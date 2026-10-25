#!/bin/bash
# Moodle 4.5.15 bundles phpoffice/phpspreadsheet 1.29.0. Scout's fixable
# critical/high gate stops the push until that library is 1.30.6.
#
# Moodle 4.5 loads the library through core_component, not through a composer
# autoloader:
#   lib/phpspreadsheet/phpspreadsheet/src   PhpOffice\PhpSpreadsheet
#   lib/phpspreadsheet/markbaker/*          Complex, Matrix (unchanged, ^3.0)
# 1.30.6 also requires composer/pcre, which core_component does not map, so the
# script adds that library and one psr-4 entry in lib/classes/component.php.
# Follows lib/phpspreadsheet/readme_moodle.txt: OLE and Xls support stay removed.
set -euo pipefail

moodle=/opt/moodle-source
dest="$moodle/lib/phpspreadsheet/phpspreadsheet"
pcre_dest="$moodle/lib/phpspreadsheet/composer/pcre"
component="$moodle/lib/classes/component.php"
thirdparty="$moodle/lib/thirdpartylibs.xml"

test -d "$dest/src/PhpSpreadsheet"
grep -q "PhpSpreadsheet::class => 'lib/phpspreadsheet/phpspreadsheet/src/PhpSpreadsheet'" "$component"
command -v composer >/dev/null

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

installed=/tmp/sheet/vendor/composer/installed.json
pcre_version=$(INSTALLED="$installed" php -r '
$d = json_decode(file_get_contents(getenv("INSTALLED")), true);
foreach (($d["packages"] ?? $d) as $p) {
    if ($p["name"] === "composer/pcre") { echo ltrim($p["version"], "v"); }
}')
grep -q '"name": "phpoffice/phpspreadsheet"' "$installed"
grep -q '"version": "1.30.6"' "$installed"
test -n "$pcre_version"

new=/tmp/sheet/vendor/phpoffice/phpspreadsheet
rm -rf \
    "$new/bin" \
    "$new/docs" \
    "$new/samples" \
    "$new/phpstan-baseline.neon" \
    "$new/phpstan-conditional.php" \
    "$new/phpstan.neon.dist" \
    "$new/src/PhpSpreadsheet/Shared/OLE.php" \
    "$new/src/PhpSpreadsheet/Shared/OLERead.php" \
    "$new/src/PhpSpreadsheet/Shared/OLE" \
    "$new/src/PhpSpreadsheet/Shared/Xls.php" \
    "$new/src/PhpSpreadsheet/Reader/Xls.php" \
    "$new/src/PhpSpreadsheet/Reader/Xls" \
    "$new/src/PhpSpreadsheet/Writer/Xls.php" \
    "$new/src/PhpSpreadsheet/Writer/Xls"
find /tmp/sheet/vendor -depth -name '.*' -exec rm -rf {} +

rm -rf "$dest" "$pcre_dest"
mkdir -p "$(dirname "$pcre_dest")"
mv "$new" "$dest"
mv /tmp/sheet/vendor/composer/pcre "$pcre_dest"
for dir in "$dest" "$pcre_dest"; do
    find "$dir" -type d -exec chmod 755 {} +
    find "$dir" -type f -exec chmod 644 {} +
done

php <<'PHP'
<?php
$path = '/opt/moodle-source/lib/classes/component.php';
$src = file_get_contents($path);
$needle = "        \\PhpOffice\\PhpSpreadsheet::class => 'lib/phpspreadsheet/phpspreadsheet/src/PhpSpreadsheet',\n";
$add = "        \\Composer\\Pcre::class => 'lib/phpspreadsheet/composer/pcre/src',\n";
if (substr_count($src, $needle) !== 1) {
    fwrite(STDERR, "PhpSpreadsheet psr-4 entry not found in component.php\n");
    exit(1);
}
if (strpos($src, $add) === false) {
    file_put_contents($path, str_replace($needle, $needle . $add, $src));
}
PHP

sed -i '/<location>phpspreadsheet\/phpspreadsheet<\/location>/,/<\/library>/ s/<version>1.29.0<\/version>/<version>1.30.6<\/version>/' \
    "$thirdparty"
if ! grep -q '<location>phpspreadsheet/composer/pcre</location>' "$thirdparty"; then
    PCRE_VERSION="$pcre_version" php <<'PHP'
<?php
$path = '/opt/moodle-source/lib/thirdpartylibs.xml';
$entry = "  <library>\n"
    . "    <location>phpspreadsheet/composer/pcre</location>\n"
    . "    <name>composer/pcre</name>\n"
    . "    <description>PCRE wrapping library that offers type-safe preg_* replacements. Required by PhpSpreadsheet.</description>\n"
    . "    <version>" . getenv('PCRE_VERSION') . "</version>\n"
    . "    <license>MIT</license>\n"
    . "    <repository>https://github.com/composer/pcre</repository>\n"
    . "    <copyrights>\n"
    . "      <copyright>2021 Composer</copyright>\n"
    . "    </copyrights>\n"
    . "  </library>\n";
$src = file_get_contents($path);
if (substr_count($src, "</libraries>") !== 1) {
    fwrite(STDERR, "</libraries> not found in thirdpartylibs.xml\n");
    exit(1);
}
file_put_contents($path, str_replace("</libraries>", $entry . "</libraries>", $src));
PHP
fi

grep -q "Composer\\\\Pcre::class => 'lib/phpspreadsheet/composer/pcre/src'" "$component"
sheet_entry=$(sed -n '/<location>phpspreadsheet\/phpspreadsheet<\/location>/,/<\/library>/p' "$thirdparty")
grep -q '<version>1.30.6</version>' <<<"$sheet_entry"
test ! -e "$dest/src/PhpSpreadsheet/Reader/Xls.php"
test -f "$pcre_dest/src/Preg.php"

# Write and read back an xlsx through Moodle's own autoloader.
php <<'PHP'
<?php
define('MOODLE_INTERNAL', true);
define('IGNORE_COMPONENT_CACHE', true);
$CFG = new stdClass();
$CFG->dirroot = '/opt/moodle-source';
$CFG->libdir = $CFG->dirroot . '/lib';
$CFG->admin = 'admin';
require($CFG->libdir . '/classes/component.php');
spl_autoload_register([core_component::class, 'classloader']);

if (!\Composer\Pcre\Preg::isMatch('/^sum$/i', 'SUM')) {
    fwrite(STDERR, "Composer\\Pcre did not load\n");
    exit(1);
}
$book = new \PhpOffice\PhpSpreadsheet\Spreadsheet();
$sheet = $book->getActiveSheet();
$sheet->setCellValue('A1', 2);
$sheet->setCellValue('A2', 3);
$sheet->setCellValue('A3', '=SUM(A1:A2)');
$file = tempnam(sys_get_temp_dir(), 'sheet') . '.xlsx';
(new \PhpOffice\PhpSpreadsheet\Writer\Xlsx($book))->save($file);
$read = \PhpOffice\PhpSpreadsheet\IOFactory::createReader('Xlsx')->load($file);
$value = $read->getActiveSheet()->getCell('A3')->getCalculatedValue();
unlink($file);
if ((int) $value !== 5) {
    fwrite(STDERR, "unexpected SUM result: {$value}\n");
    exit(1);
}
echo "PhpSpreadsheet 1.30.6 loads through core_component\n";
PHP

rm -rf /tmp/sheet
