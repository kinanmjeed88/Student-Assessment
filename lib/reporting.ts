import { Platform } from "react-native";
import * as Print from "expo-print";
import * as Sharing from "expo-sharing";
import * as FileSystem from "expo-file-system/legacy";
import * as XLSX from "xlsx";
import type { AppData, Student } from "@/lib/student-store";
import { attendanceLabels, behaviorLabels, noteLabels } from "@/lib/student-store";

const safe = (value?: string | number) => String(value ?? "—").replace(/[&<>'"]/g, (character) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" }[character] ?? character));
const date = (value: string) => new Intl.DateTimeFormat("ar", { year: "numeric", month: "long", day: "numeric" }).format(new Date(value));

function className(data: AppData, student: Student) {
  const schoolClass = data.classes.find((item) => item.id === student.classId)?.name ?? "—";
  const section = data.sections.find((item) => item.id === student.sectionId)?.name ?? "—";
  return `${schoolClass} — شعبة ${section}`;
}

function layout(title: string, data: AppData, body: string) {
  return `<!DOCTYPE html><html dir="rtl" lang="ar"><head><meta charset="utf-8"/><style>@page{size:A4;margin:14mm}*{box-sizing:border-box}body{font-family:Arial,'Noto Naskh Arabic',sans-serif;color:#172B4D;direction:rtl;font-size:12px;line-height:1.6}.head{border-bottom:2px solid #12355B;padding-bottom:10px;margin-bottom:14px}.school{font-size:18px;font-weight:700;color:#12355B}.sub{color:#607084}.title{font-size:16px;font-weight:700;margin:18px 0 8px;color:#12355B}table{width:100%;border-collapse:collapse;margin:8px 0 16px}th{background:#E9F1FA;color:#12355B}th,td{border:1px solid #D7E0EA;padding:6px;text-align:right;vertical-align:top}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}.card{border:1px solid #D7E0EA;border-radius:7px;padding:8px}.number{font-size:20px;font-weight:700;color:#12355B}.footer{position:fixed;bottom:0;left:0;right:0;border-top:1px solid #D7E0EA;color:#607084;padding-top:4px;font-size:10px}</style></head><body><div class="head"><div class="school">${safe(data.settings.schoolName || "سجل الطالب")}</div><div class="sub">المدرس: ${safe(data.settings.teacherName || "غير محدد")} | العام الدراسي: ${safe(data.settings.academicYear)}</div></div><h1>${safe(title)}</h1>${body}<div class="footer">تاريخ الإنشاء: ${date(new Date().toISOString())}</div></body></html>`;
}

export function buildSchoolReport(data: AppData) {
  const todayKey = new Date().toISOString().slice(0, 10);
  const todayRecords = data.attendance.filter((record) => record.date === todayKey);
  const present = todayRecords.filter((record) => record.status === "present").length;
  const body = `<div class="grid"><div class="card"><div>إجمالي الطلاب</div><div class="number">${data.students.length}</div></div><div class="card"><div>الصفوف</div><div class="number">${data.classes.length}</div></div><div class="card"><div>حضور اليوم</div><div class="number">${present}</div></div></div><h2 class="title">كشف الطلاب</h2><table><thead><tr><th>الرقم</th><th>اسم الطالب</th><th>الصف والشعبة</th><th>حالة الطالب</th></tr></thead><tbody>${data.students.map((student) => `<tr><td>${safe(student.studentNumber)}</td><td>${safe(student.fullName)}</td><td>${safe(className(data, student))}</td><td>${safe(student.status)}</td></tr>`).join("") || "<tr><td colspan='4'>لا توجد بيانات طلاب مسجلة.</td></tr>"}</tbody></table>`;
  return layout("تقرير المدرسة العام", data, body);
}

export function buildStudentReport(data: AppData, student: Student) {
  const attendance = data.attendance.filter((record) => record.studentId === student.id).sort((a, b) => b.date.localeCompare(a.date));
  const grades = data.grades.filter((grade) => grade.studentId === student.id);
  const behaviors = data.behaviors.filter((item) => item.studentId === student.id);
  const notes = data.notes.filter((item) => item.studentId === student.id);
  const attendanceRows = attendance.map((record) => `<tr><td>${safe(date(record.date))}</td><td>${safe(attendanceLabels[record.status])}</td><td>${safe(record.reason)}</td><td>${safe(record.notes)}</td></tr>`).join("") || "<tr><td colspan='4'>لا يوجد سجل حضور.</td></tr>";
  const gradeRows = grades.map((grade) => { const field = data.gradeFields.find((item) => item.id === grade.fieldId); return `<tr><td>${safe(field?.subject)}</td><td>${safe(field?.title)}</td><td>${safe(grade.score)}</td><td>${safe(field?.maxScore)}</td></tr>`; }).join("") || "<tr><td colspan='4'>لا توجد درجات.</td></tr>";
  const behaviorRows = behaviors.map((item) => `<tr><td>${safe(date(item.date))}</td><td>${safe(behaviorLabels[item.category])}</td><td>${safe(item.title)}</td><td>${safe(item.details)}</td></tr>`).join("") || "<tr><td colspan='4'>لا توجد سجلات سلوك.</td></tr>";
  const noteRows = notes.map((item) => `<tr><td>${safe(date(item.date))}</td><td>${safe(noteLabels[item.category])}</td><td>${safe(item.title)}</td><td>${safe(item.details)}</td></tr>`).join("") || "<tr><td colspan='4'>لا توجد ملاحظات.</td></tr>";
  const body = `<table><tbody><tr><th>اسم الطالب</th><td>${safe(student.fullName)}</td><th>رقم الطالب</th><td>${safe(student.studentNumber)}</td></tr><tr><th>الصف والشعبة</th><td>${safe(className(data, student))}</td><th>ولي الأمر</th><td>${safe(student.guardianName)}</td></tr></tbody></table><h2 class="title">الحضور والغياب</h2><table><thead><tr><th>التاريخ</th><th>الحالة</th><th>السبب</th><th>ملاحظات</th></tr></thead><tbody>${attendanceRows}</tbody></table><h2 class="title">الدرجات</h2><table><thead><tr><th>المادة</th><th>التقييم</th><th>درجة الطالب</th><th>العظمى</th></tr></thead><tbody>${gradeRows}</tbody></table><h2 class="title">السلوك</h2><table><thead><tr><th>التاريخ</th><th>التصنيف</th><th>العنوان</th><th>التفاصيل</th></tr></thead><tbody>${behaviorRows}</tbody></table><h2 class="title">الملاحظات</h2><table><thead><tr><th>التاريخ</th><th>النوع</th><th>العنوان</th><th>التفاصيل</th></tr></thead><tbody>${noteRows}</tbody></table>`;
  return layout(`الملف الشامل للطالب: ${student.fullName}`, data, body);
}

export async function sharePdf(html: string, filename: string) {
  if (Platform.OS === "web") { await Print.printAsync({}); return; }
  const { uri } = await Print.printToFileAsync({ html, width: 595, height: 842 });
  if (await Sharing.isAvailableAsync()) await Sharing.shareAsync(uri, { mimeType: "application/pdf", UTI: "com.adobe.pdf", dialogTitle: `مشاركة ${filename}` });
}

export async function shareWorkbook(data: AppData, filename: string) {
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, XLSX.utils.json_to_sheet(data.students.map((student) => ({ "رقم الطالب": student.studentNumber, "اسم الطالب": student.fullName, "الصف": data.classes.find((item) => item.id === student.classId)?.name ?? "", "الشعبة": data.sections.find((item) => item.id === student.sectionId)?.name ?? "", "الحالة": student.status }))), "الطلاب");
  XLSX.utils.book_append_sheet(workbook, XLSX.utils.json_to_sheet(data.attendance.map((record) => ({ "التاريخ": record.date, "اسم الطالب": data.students.find((student) => student.id === record.studentId)?.fullName ?? "", "الحالة": attendanceLabels[record.status], "السبب": record.reason ?? "", "ملاحظات": record.notes ?? "" }))), "الحضور");
  XLSX.utils.book_append_sheet(workbook, XLSX.utils.json_to_sheet(data.grades.map((grade) => { const field = data.gradeFields.find((item) => item.id === grade.fieldId); return { "اسم الطالب": data.students.find((student) => student.id === grade.studentId)?.fullName ?? "", "المادة": field?.subject ?? "", "التقييم": field?.title ?? "", "الدرجة": grade.score, "العظمى": field?.maxScore ?? "" }; })), "الدرجات");
  const base64 = XLSX.write(workbook, { type: "base64", bookType: "xlsx" });
  if (Platform.OS === "web") return;
  const uri = `${FileSystem.cacheDirectory}${filename}.xlsx`;
  await FileSystem.writeAsStringAsync(uri, base64, { encoding: FileSystem.EncodingType.Base64 });
  if (await Sharing.isAvailableAsync()) await Sharing.shareAsync(uri, { mimeType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", dialogTitle: `مشاركة ${filename}` });
}

export async function shareStudentWorkbook(data: AppData, student: Student, filename: string) {
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, XLSX.utils.json_to_sheet([{ "رقم الطالب": student.studentNumber, "اسم الطالب": student.fullName, "الصف": className(data, student), "الحالة": student.status, "ولي الأمر": student.guardianName ?? "", "الهاتف": student.guardianPhone ?? "" }]), "بيانات الطالب");
  XLSX.utils.book_append_sheet(workbook, XLSX.utils.json_to_sheet(data.attendance.filter((record) => record.studentId === student.id).map((record) => ({ "التاريخ": record.date, "الحالة": attendanceLabels[record.status], "السبب": record.reason ?? "", "الملاحظات": record.notes ?? "" }))), "الحضور");
  XLSX.utils.book_append_sheet(workbook, XLSX.utils.json_to_sheet(data.grades.filter((grade) => grade.studentId === student.id).map((grade) => { const field = data.gradeFields.find((item) => item.id === grade.fieldId); return { "المادة": field?.subject ?? "", "التقييم": field?.title ?? "", "الدرجة": grade.score, "العظمى": field?.maxScore ?? "", "النسبة": field ? `${Math.round((grade.score / field.maxScore) * 100)}%` : "" }; })), "الدرجات");
  XLSX.utils.book_append_sheet(workbook, XLSX.utils.json_to_sheet(data.behaviors.filter((item) => item.studentId === student.id).map((item) => ({ "التاريخ": item.date, "التصنيف": behaviorLabels[item.category], "العنوان": item.title, "التفاصيل": item.details, "الإجراء": item.actionTaken ?? "" }))), "السلوك");
  XLSX.utils.book_append_sheet(workbook, XLSX.utils.json_to_sheet(data.notes.filter((item) => item.studentId === student.id).map((item) => ({ "التاريخ": item.date, "النوع": noteLabels[item.category], "العنوان": item.title, "التفاصيل": item.details, "متابعة": item.needsFollowUp ? "نعم" : "لا" }))), "الملاحظات");
  const base64 = XLSX.write(workbook, { type: "base64", bookType: "xlsx" });
  if (Platform.OS === "web") return;
  const uri = `${FileSystem.cacheDirectory}${filename}.xlsx`;
  await FileSystem.writeAsStringAsync(uri, base64, { encoding: FileSystem.EncodingType.Base64 });
  if (await Sharing.isAvailableAsync()) await Sharing.shareAsync(uri, { mimeType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", dialogTitle: `مشاركة ${filename}` });
}
