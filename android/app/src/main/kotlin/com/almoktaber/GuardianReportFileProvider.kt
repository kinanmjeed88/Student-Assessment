package com.almoktaber

import androidx.core.content.FileProvider

/**
 * يوفّر FileProvider مخصص لتقارير ولي الأمر.

 * استخدام فئة فرعية يمنع تعارض السلطة (authority) مع أي FileProvider آخر
 * تضيفه الحزم الأخرى في التطبيق.
 */
class GuardianReportFileProvider : FileProvider()
