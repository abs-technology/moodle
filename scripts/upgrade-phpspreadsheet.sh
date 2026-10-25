#!/bin/bash
# Moodle 4.3.12 vendors phpoffice/phpspreadsheet 1.29.0. Scout's fixable
# critical/high gate stops the push until that library is 1.30.6.
set -euo pipefail

dest=/opt/moodle-source/lib/phpspreadsheet/vendor
test -f /opt/moodle-source/lib/excellib.class.php

curl -fsSL https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
mkdir -p /tmp/sheet
cat > /tmp/sheet/composer.json <<'EOF'
{
    "require": {
        "phpoffice/phpspreadsheet": "1.30.6"
    },
    "replace": {
        "ezyang/htmlpurifier": "*",
        "maennchen/zipstream-php": "*",
        "myclabs/php-enum": "*",
        "symfony/polyfill-mbstring": "*"
    }
}
EOF

COMPOSER_ALLOW_SUPERUSER=1 composer update \
    --no-dev --no-interaction --no-progress --working-dir=/tmp/sheet

rm -rf \
    /tmp/sheet/vendor/phpoffice/phpspreadsheet/bin \
    /tmp/sheet/vendor/phpoffice/phpspreadsheet/docs \
    /tmp/sheet/vendor/phpoffice/phpspreadsheet/samples
find /tmp/sheet/vendor -depth -name '.*' -exec rm -rf {} +

php -r '
$path = "/tmp/sheet/vendor/phpoffice/phpspreadsheet/src/PhpSpreadsheet/Shared/File.php";
$src = file_get_contents($path);
$needle = "public static function sysGetTempDir(): string\n    {\n";
$hack = $needle
    . "        // Moodle hack!\n"
    . "        if (function_exists('\''make_temp_directory'\'')) {\n"
    . "            \$temp = make_temp_directory('\''phpspreadsheet'\'');\n"
    . "            return realpath(dirname(\$temp));\n"
    . "        }\n\n";
if (strpos($src, $needle) === false) {
    fwrite(STDERR, "sysGetTempDir() not found\n");
    exit(1);
}
if (strpos($src, "Moodle hack") === false) {
    $src = str_replace($needle, $hack, $src);
    file_put_contents($path, $src);
}
'

rm -rf "$dest"
mv /tmp/sheet/vendor "$dest"
find "$dest" -type d -exec chmod 755 {} +
find "$dest" -type f -exec chmod 644 {} +
sed -i '/<location>phpspreadsheet<\/location>/,/<\/library>/ s/<version>1.29.0<\/version>/<version>1.30.6<\/version>/' \
    /opt/moodle-source/lib/thirdpartylibs.xml

grep -q '"version": "1.30.6"' "$dest/composer/installed.json"
grep -q 'Moodle hack' "$dest/phpoffice/phpspreadsheet/src/PhpSpreadsheet/Shared/File.php"
grep -q '<version>1.30.6</version>' /opt/moodle-source/lib/thirdpartylibs.xml
rm -rf /tmp/sheet /usr/local/bin/composer
