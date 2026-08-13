import PyPDF2
with open("qkd_post_processing/week3.pdf", "rb") as f:
    reader = PyPDF2.PdfReader(f)
    text = "\n".join([p.extract_text() for p in reader.pages])

with open("week3_text.txt", "w", encoding="utf-8") as f:
    f.write(text)
