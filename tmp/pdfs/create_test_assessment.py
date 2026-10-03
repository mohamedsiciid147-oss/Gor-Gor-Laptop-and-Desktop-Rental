from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak

OUTPUT = 'output/pdf/Gor_Gor_Test_Assessment_English.pdf'

rows = [
    ('TC-01', 'Student registration and catalogue', 'Institutional email, a six-digit password, account creation, and dashboard redirect are implemented.', 'Implemented'),
    ('TC-02', 'Duplicate or invalid email', 'Invalid emails, duplicate emails, and passwords that are not six digits are rejected.', 'Implemented'),
    ('TC-03', 'Correct student login', 'A valid student login opens the student dashboard.', 'Implemented'),
    ('TC-04', 'Incorrect password', 'Access is denied and an error message is shown.', 'Implemented'),
    ('TC-05', 'Admin role separation', 'An admin is routed to the Admin Dashboard; a student is routed to the Student Dashboard.', 'Implemented'),
    ('TC-06', 'Device catalogue and status', 'Available, Reserved, Rented Out, and Maintenance states are shown.', 'Implemented'),
    ('TC-07', 'Automatic status update', 'The student catalogue refreshes every five seconds without a manual refresh.', 'Implemented'),
    ('TC-08', 'Book an available device', 'Bookings are created; future bookings display Reserved and active rentals display Rented Out.', 'Implemented'),
    ('TC-09', 'Prevent double booking', 'The application checks conflicting dates and includes a database overlap-protection migration.', 'Requires live test'),
    ('TC-10', 'View booking history', 'My Bookings displays the student bookings, dates, and statuses.', 'Implemented'),
    ('TC-11', 'Admin adds a device', 'The Device Management screen can add devices with specifications.', 'Implemented'),
    ('TC-12', 'Admin updates or removes a device', 'Devices can be edited or removed, and the catalogue updates automatically.', 'Implemented'),
    ('TC-13', 'Admin records a payment', 'No payment record, linked payment data, or balance update module exists.', 'Not implemented'),
    ('TC-14', 'Student payment history', 'No payment-history feature exists for students.', 'Not implemented'),
    ('TC-15', 'Booking confirmation notification', 'Students receive in-app booking confirmation and status notifications.', 'Implemented'),
    ('TC-16', 'Due-date reminder', 'An in-app reminder appears the day before and on the due date for confirmed bookings.', 'Implemented'),
    ('TC-17', 'Dashboard summary accuracy', 'Devices, active bookings, users, and revenue are shown; pending payments and overdue totals are absent.', 'Partially implemented'),
    ('TC-18', 'Row Level Security (RLS)', 'Supabase Auth and RLS policies have not yet been added or verified.', 'Not implemented'),
]

styles = getSampleStyleSheet()
title = ParagraphStyle('Title', parent=styles['Title'], fontName='Helvetica-Bold', fontSize=20, leading=25, textColor=colors.HexColor('#151843'), alignment=TA_CENTER, spaceAfter=8)
subtitle = ParagraphStyle('Subtitle', parent=styles['Normal'], fontSize=10, leading=14, textColor=colors.HexColor('#52627e'), alignment=TA_CENTER, spaceAfter=16)
heading = ParagraphStyle('Heading', parent=styles['Heading2'], fontName='Helvetica-Bold', fontSize=14, leading=18, textColor=colors.HexColor('#151843'), spaceBefore=8, spaceAfter=8)
body = ParagraphStyle('Body', parent=styles['BodyText'], fontSize=9, leading=13, textColor=colors.HexColor('#252939'))
cell = ParagraphStyle('Cell', parent=body, fontSize=7.2, leading=9)
header_cell = ParagraphStyle('HeaderCell', parent=cell, fontName='Helvetica-Bold', textColor=colors.white, alignment=TA_CENTER)

def p(value, style=cell):
    return Paragraph(value, style)

def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont('Helvetica', 8)
    canvas.setFillColor(colors.HexColor('#6b7194'))
    canvas.drawString(18 * mm, 12 * mm, 'Gor Gor Laptop and Desktop Rental Management System')
    canvas.drawRightString(192 * mm, 12 * mm, f'Page {doc.page}')
    canvas.restoreState()

doc = SimpleDocTemplate(OUTPUT, pagesize=A4, rightMargin=14 * mm, leftMargin=14 * mm, topMargin=15 * mm, bottomMargin=20 * mm)
story = [
    Paragraph('Gor Gor Rental Management System', title),
    Paragraph('Testing Requirements Assessment - English', subtitle),
    Paragraph('Assessment basis', heading),
    Paragraph('This report is a code-based readiness assessment after the latest implementation changes. “Implemented” means the required behaviour is present in the application code. A formal Pass result must still be recorded only after the live test steps are performed on the deployed build.', body),
    Spacer(1, 10),
]

table_data = [[p('Test ID', header_cell), p('Test case', header_cell), p('Assessment', header_cell), p('Status', header_cell)]]
for test_id, test_case, assessment, status in rows:
    table_data.append([p(test_id), p(test_case), p(assessment), p(status)])

table = Table(table_data, colWidths=[18 * mm, 40 * mm, 95 * mm, 31 * mm], repeatRows=1)
table.setStyle(TableStyle([
    ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#3e25cb')),
    ('GRID', (0, 0), (-1, -1), 0.35, colors.HexColor('#dfe3ee')),
    ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ('LEFTPADDING', (0, 0), (-1, -1), 5),
    ('RIGHTPADDING', (0, 0), (-1, -1), 5),
    ('TOPPADDING', (0, 0), (-1, -1), 6),
    ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
    ('BACKGROUND', (0, 1), (-1, -1), colors.white),
    ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#f8f9fd')]),
]))
story.append(table)
story.extend([
    Spacer(1, 14),
    Paragraph('Summary', heading),
    Paragraph('Implemented: 13 test requirements. Requires live test: 1 requirement (TC-09). Partially implemented: 1 requirement (TC-17). Not implemented: 3 requirements (TC-13, TC-14, and TC-18).', body),
    Spacer(1, 8),
    Paragraph('System test readiness', heading),
    Paragraph('SYS-01 is not complete because payment recording is missing. SYS-02 is ready for live testing. SYS-03 is not complete because rental extension is missing. Performance timings and User Acceptance Testing (UAT) must be measured with real users and real devices before being entered as final results.', body),
])

doc.build(story, onFirstPage=footer, onLaterPages=footer)
