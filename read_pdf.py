import PyPDF2
with open("paper/Blind_Reconciliation_with_Protograph_LDPC_Code_Extension_for_FSO-Based_Satellite_QKD_Systems.pdf", "rb") as f:
    reader = PyPDF2.PdfReader(f)
    text = "\n".join([p.extract_text() for p in reader.pages])

with open("paper6_text.txt", "w", encoding="utf-8") as f:
    f.write(text)
