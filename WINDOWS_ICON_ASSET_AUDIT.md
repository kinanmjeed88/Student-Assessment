# Windows icon asset audit

تمت معاينة `assets/images/splash_icon.png` و`assets/images/favicon.png` في فرع Windows 7، وكلتاهما متطابقتان بصرياً وبالأبعاد نفسها (1024×1024). الأصل المعتمد لأيقونة Windows هو `splash_icon.png`، وهو شعار سجل الطالب الأزرق مع علامة التحقق الخضراء، وليس أيقونة Flutter الافتراضية.

سيتم تحويل الأصل إلى ملف `windows/runner/resources/app_icon.ico` متعدد الأحجام، ثم استخدامه في Runner.rc في فرعي Windows 7 وWindows 10/11. لا يلزم تعديل Android.
