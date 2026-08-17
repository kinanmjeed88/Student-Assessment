import * as XLSX from "xlsx";
import { describe, expect, it } from "vitest";
import { cleanStudentName, deduplicateStudentNames, namesFromExcelBytes, namesFromText, namesFromWordDocumentXml, studentNameParts } from "../lib/student-import-format";

describe("استيراد أسماء الطلاب", () => {
  it("ينظف الترقيم التسلسلي ويحافظ على الاسم الرباعي واللقب", () => {
    expect(cleanStudentName("١. أحمد حمزة كاظم علي الصياد")).toBe("أحمد حمزة كاظم علي الصياد");
    expect(studentNameParts("أحمد حمزة كاظم علي الصياد")).toEqual({ firstName: "أحمد", fatherName: "حمزة", lastName: "كاظم علي الصياد" });
  });

  it("يستخرج الأسماء من نص أو CSV سطرًا بسطر ويتجاهل العناوين", () => {
    const parsed = namesFromText("اسم الطالب\n1, أحمد حمزة كاظم علي الصياد\n2- علي حسن محمد العبيدي\n");
    expect(parsed.names).toEqual(["أحمد حمزة كاظم علي الصياد", "علي حسن محمد العبيدي"]);
  });

  it("يستخرج عمود الاسم من Excel دون أرقام التسلسل", () => {
    const workbook = XLSX.utils.book_new();
    const sheet = XLSX.utils.aoa_to_sheet([
      ["ت", "اسم الطالب"],
      [1, "أحمد حمزة كاظم علي الصياد"],
      [2, "علي حسن محمد العبيدي"],
    ]);
    XLSX.utils.book_append_sheet(workbook, sheet, "طلاب الأول أ");
    const bytes = new Uint8Array(XLSX.write(workbook, { bookType: "xlsx", type: "array" }) as ArrayBuffer);
    expect(namesFromExcelBytes(bytes).names).toEqual(["أحمد حمزة كاظم علي الصياد", "علي حسن محمد العبيدي"]);
  });

  it("يستخرج الفقرات من ملف Word حديث", () => {
    const xml = `<w:document><w:body><w:p><w:r><w:t>1. أحمد حمزة كاظم علي الصياد</w:t></w:r></w:p><w:p><w:r><w:t>2. علي حسن محمد العبيدي</w:t></w:r></w:p></w:body></w:document>`;
    expect(namesFromWordDocumentXml(xml).names).toEqual(["أحمد حمزة كاظم علي الصياد", "علي حسن محمد العبيدي"]);
  });

  it("يمنع التكرار داخل الملف ومع الأسماء المخزنة سابقًا", () => {
    const result = deduplicateStudentNames(
      ["أحمد حمزة كاظم علي الصياد", "احمد حمزة كاظم علي الصياد", "علي حسن محمد العبيدي"],
      ["حسن علي محمد الجبوري"],
    );
    expect(result.accepted).toEqual(["أحمد حمزة كاظم علي الصياد", "علي حسن محمد العبيدي"]);
    expect(result.duplicateNames).toEqual(["احمد حمزة كاظم علي الصياد"]);
  });
});
