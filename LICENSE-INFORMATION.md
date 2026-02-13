# License Information - ABS Technology Moodle LMS

## 📄 **Primary License**

This project uses **GNU General Public License v3.0 (GPL-3.0)** which is the official license for Moodle LMS.

### Moodle License
- **Project:** Moodle LMS  
- **License:** GNU GPLv3+
- **Source:** https://moodle.org/
- **License URL:** https://www.gnu.org/licenses/gpl-3.0.html

---

## 📦 **Component Licenses**

### 1. **Moodle Core** (GPL-3.0+)
The Moodle Learning Management System core is licensed under the GNU General Public License version 3 or later.

### 2. **PHP Dependencies**
Third-party PHP libraries included via Composer may have various licenses:
- **MIT License** - Most Symfony components
- **BSD License** - Some utility libraries  
- **GPL/LGPL** - Some educational/academic libraries

### 3. **System Packages**
- **Debian packages:** Mix of GPL, LGPL, Apache, MIT, and other OSI-approved licenses
- **Apache HTTP Server:** Apache License 2.0
- **PHP:** PHP License 3.01
- **MariaDB Client:** GPL-2.0

---

## ⚠️ **About AGPL v3 Detection**

Docker Scout and some security scanners may report **AGPL v3 licenses found**. This is expected and acceptable because:

### Why AGPL/GPL is detected:
1. **Moodle itself** uses GPL v3 (similar to AGPL)
2. Some **Moodle plugins** may use AGPL v3
3. This is **intentional** and part of Moodle's open-source nature

### Is this a problem?
**NO** - This is acceptable for several reasons:

✅ **Open Source Compliance**
- Moodle is an official GPL v3+ project
- All modifications and distributions respect the license
- Source code is publicly available

✅ **Google Cloud Marketplace**
- Google allows GPL/AGPL licensed software
- Many popular Marketplace solutions use GPL (WordPress, Drupal, etc.)
- As long as licenses are properly disclosed (which we do)

✅ **Enterprise Usage**
- GPL/AGPL does not restrict **internal use**
- Only requires source distribution if you **distribute** modified versions
- Does not affect end-user rights

---

## 🔐 **Security Scanner Warnings**

When running security scans (Docker Scout, Trivy, etc.), you may see:

```
⚠️  AGPL v3 licenses found
```

**This is informational, not a vulnerability**. It simply means:
- The scanner detected GPL/AGPL licensed components
- You should be aware of license obligations
- **No security risk** - just license compliance awareness

---

## 📋 **License Obligations**

### If you USE this Docker image:
✅ **No additional obligations** - Just use it

### If you MODIFY and DISTRIBUTE this image:
You must:
1. ✅ Keep the GPL v3 license
2. ✅ Provide source code of modifications
3. ✅ Document changes made
4. ✅ Maintain copyright notices

### If you OFFER this as a SERVICE (SaaS):
- ✅ **No distribution** = No obligation to share source
- ✅ Users can request source code under GPL
- ✅ Best practice: Be transparent about modifications

---

## 🎓 **Moodle License Compliance**

### We comply with Moodle's GPL v3 by:

1. **Source Code Availability**
   - GitHub repository: https://github.com/abs-technology/moodle
   - All modifications documented
   - Dockerfile and scripts publicly available

2. **Attribution**
   - Moodle™ trademark properly attributed
   - Original authors credited
   - Copyright notices maintained

3. **No License Changes**
   - We do NOT relicense Moodle
   - We do NOT remove license terms
   - We ADD value while respecting GPL

---

## 📚 **Third-Party Licenses**

### PHP Composer Dependencies

To view all licenses of included packages:

```bash
docker run --rm abstechnology/moodle-standard:4.5.10 \
  bash -c "cd /opt/moodle-source && composer licenses"
```

### Common licenses included:
- **MIT License** - Symfony, PHPUnit, and many others
- **BSD-3-Clause** - Some utility libraries
- **GPL-3.0-or-later** - Moodle core and some plugins
- **LGPL-2.1** - Some GNU libraries

---

## ✅ **License Compatibility**

All included licenses are **compatible** with GPL v3:
- MIT → GPL v3 ✅
- BSD → GPL v3 ✅  
- Apache 2.0 → GPL v3 ✅
- LGPL → GPL v3 ✅

**Result:** This Docker image is fully GPL v3 compliant

---

## 🏢 **For Enterprise Users**

### Using this image in your organization:

**✅ Allowed:**
- Internal deployment and use
- Customization for internal needs
- Creating backups and replicas
- Performance optimization

**⚠️ Requires Care:**
- Distributing modified versions (must share source)
- Offering as a product (must comply with GPL)
- Removing copyright notices (prohibited)

**💡 Best Practice:**
- Keep modifications internal if possible
- Contribute improvements back to community
- Document your customizations

---

## 📞 **Questions About Licensing?**

### Official Resources:
- **Moodle License:** https://docs.moodle.org/dev/License
- **GPL v3 FAQ:** https://www.gnu.org/licenses/gpl-faq.html
- **GPL v3 Full Text:** https://www.gnu.org/licenses/gpl-3.0.html

### Contact:
- **Email:** billnguyen@absi.edu.vn
- **Website:** https://abs.education/

---

## 🎯 **Summary**

| Question | Answer |
|----------|--------|
| Can I use this for free? | ✅ Yes |
| Can I use commercially? | ✅ Yes |
| Can I modify it? | ✅ Yes |
| Must I share modifications? | ⚠️ Only if distributing |
| Can I sell services using this? | ✅ Yes |
| Must I open-source my custom plugins? | ⚠️ Only if distributing |
| Is AGPL warning a security issue? | ❌ No, just informational |

---

**Last Updated:** February 13, 2026  
**License Version:** GPL-3.0-or-later  
**Moodle Version:** 4.5.10+
