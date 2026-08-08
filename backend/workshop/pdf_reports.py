from io import BytesIO
from decimal import Decimal

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import (
    SimpleDocTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
    Image,
)

from .models import WorkshopSettings


ORANGE = colors.HexColor('#E8590C')
CHARCOAL = colors.HexColor('#1B1F24')
SOFT = colors.HexColor('#5B6570')


def money(value, currency='AED'):
    return f'{currency} {Decimal(value or 0):,.2f}'


def build_invoice_pdf(job):
    settings = WorkshopSettings.get_solo()

    buffer = BytesIO()

    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=16 * mm,
        bottomMargin=16 * mm,
    )

    styles = getSampleStyleSheet()

    styles.add(
        ParagraphStyle(
            name='Brand',
            parent=styles['Heading1'],
            fontSize=18,
            textColor=CHARCOAL,
            spaceAfter=2,
        )
    )

    styles.add(
        ParagraphStyle(
            name='SmallSoft',
            parent=styles['Normal'],
            fontSize=8.5,
            textColor=SOFT,
            leading=11,
        )
    )

    styles.add(
        ParagraphStyle(
            name='SectionPCC',
            parent=styles['Heading3'],
            fontSize=10,
            textColor=SOFT,
            borderColor=ORANGE,
            borderWidth=0,
            leftIndent=5,
            spaceBefore=10,
            spaceAfter=5,
        )
    )

    styles.add(
        ParagraphStyle(
            name='Right',
            parent=styles['Normal'],
            alignment=TA_RIGHT,
        )
    )

    contact = '<br/>'.join(
        filter(
            None,
            [
                settings.address,
                settings.phone,
                settings.email,
                settings.license_number,
            ],
        )
    )

    # ---------------------------------------------------------
    # WORKSHOP LOGO
    # Uses the logo uploaded from Workshop Settings.
    # Falls back to PCC only when no usable logo exists.
    # ---------------------------------------------------------
    if settings.logo:
        try:
            invoice_logo = Image(
                settings.logo.path,
                width=18 * mm,
                height=18 * mm,
                kind='proportional',
            )
        except Exception:
            invoice_logo = Paragraph(
                'PCC',
                ParagraphStyle(
                    'Badge',
                    parent=styles['Heading2'],
                    alignment=TA_CENTER,
                    textColor=CHARCOAL,
                ),
            )
    else:
        invoice_logo = Paragraph(
            'PCC',
            ParagraphStyle(
                'Badge',
                parent=styles['Heading2'],
                alignment=TA_CENTER,
                textColor=CHARCOAL,
            ),
        )

    header = Table(
        [
            [
                invoice_logo,
                Paragraph(
                    f'<b>{settings.name}</b><br/>'
                    f'<font size="9" color="#5B6570">'
                    f'Workshop Job Invoice'
                    f'</font>',
                    styles['Brand'],
                ),
            ],
        ],
        colWidths=[22 * mm, 142 * mm],
    )

    header.setStyle(
        TableStyle(
            [
                ('BACKGROUND', (0, 0), (0, 0), ORANGE),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('BOX', (0, 0), (0, 0), 1, CHARCOAL),
                ('LINEBELOW', (0, 0), (-1, -1), 3, ORANGE),
                ('LEFTPADDING', (1, 0), (1, 0), 8),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
            ]
        )
    )

    story = [
        header,
        Spacer(1, 5),
        Paragraph(
            contact or ' ',
            styles['SmallSoft'],
        ),
        Spacer(1, 10),
    ]

    info = Table(
        [
            ['Invoice No.', job.invoice_number],
            [
                'Date / Time',
                job.created_at.strftime('%d %b %Y, %I:%M %p'),
            ],
            ['Vehicle Plate', job.plate_number],
            ['Status', job.get_status_display()],
        ],
        colWidths=[40 * mm, 124 * mm],
    )

    info.setStyle(
        TableStyle(
            [
                ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
                ('TEXTCOLOR', (0, 0), (0, -1), SOFT),
                (
                    'LINEBELOW',
                    (0, 0),
                    (-1, -1),
                    .4,
                    colors.HexColor('#DDDDDD'),
                ),
                ('TOPPADDING', (0, 0), (-1, -1), 5),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
            ]
        )
    )

    story += [info]

    if job.photo:
        try:
            image = Image(
                job.photo.path,
                width=164 * mm,
                height=92 * mm,
                kind='proportional',
            )

            story += [
                Spacer(1, 8),
                image,
            ]

        except Exception:
            pass

    story += [
        Paragraph(
            'WORK DESCRIPTION',
            styles['SectionPCC'],
        ),
        Paragraph(
            job.work_description.replace(
                '\n',
                '<br/>',
            ),
            styles['Normal'],
        ),
    ]

    part_rows = [
        [
            'Part / Material',
            'Amount',
        ]
    ]

    for part in job.parts.all():
        part_rows.append(
            [
                part.name,
                money(
                    part.amount,
                    settings.currency,
                ),
            ]
        )

    if len(part_rows) == 1:
        part_rows.append(
            [
                'No parts itemized',
                money(
                    0,
                    settings.currency,
                ),
            ]
        )

    parts_table = Table(
        part_rows,
        colWidths=[
            120 * mm,
            44 * mm,
        ],
    )

    parts_table.setStyle(
        TableStyle(
            [
                (
                    'BACKGROUND',
                    (0, 0),
                    (-1, 0),
                    CHARCOAL,
                ),
                (
                    'TEXTCOLOR',
                    (0, 0),
                    (-1, 0),
                    colors.white,
                ),
                (
                    'FONTNAME',
                    (0, 0),
                    (-1, 0),
                    'Helvetica-Bold',
                ),
                (
                    'ALIGN',
                    (1, 0),
                    (1, -1),
                    'RIGHT',
                ),
                (
                    'GRID',
                    (0, 0),
                    (-1, -1),
                    .4,
                    colors.HexColor('#DDDDDD'),
                ),
                (
                    'TOPPADDING',
                    (0, 0),
                    (-1, -1),
                    6,
                ),
                (
                    'BOTTOMPADDING',
                    (0, 0),
                    (-1, -1),
                    6,
                ),
            ]
        )
    )

    story += [
        Paragraph(
            'PARTS & MATERIALS',
            styles['SectionPCC'],
        ),
        parts_table,
    ]

    totals = Table(
        [
            [
                'Materials Subtotal',
                money(
                    job.materials_total,
                    settings.currency,
                ),
            ],
            [
                'Labour Charges',
                money(
                    job.labour_charges,
                    settings.currency,
                ),
            ],
            [
                'TOTAL DUE',
                money(
                    job.total,
                    settings.currency,
                ),
            ],
        ],
        colWidths=[
            120 * mm,
            44 * mm,
        ],
    )

    totals.setStyle(
        TableStyle(
            [
                (
                    'ALIGN',
                    (1, 0),
                    (1, -1),
                    'RIGHT',
                ),
                (
                    'FONTNAME',
                    (0, 2),
                    (-1, 2),
                    'Helvetica-Bold',
                ),
                (
                    'FONTSIZE',
                    (0, 2),
                    (-1, 2),
                    13,
                ),
                (
                    'LINEABOVE',
                    (0, 2),
                    (-1, 2),
                    1.5,
                    CHARCOAL,
                ),
                (
                    'TOPPADDING',
                    (0, 0),
                    (-1, -1),
                    6,
                ),
                (
                    'BOTTOMPADDING',
                    (0, 0),
                    (-1, -1),
                    6,
                ),
            ]
        )
    )

    story += [
        Paragraph(
            'CHARGES',
            styles['SectionPCC'],
        ),
        totals,
        Spacer(1, 18),
        Paragraph(
            settings.invoice_footer,
            ParagraphStyle(
                'Footer',
                parent=styles['SmallSoft'],
                alignment=TA_CENTER,
            ),
        ),
    ]

    doc.build(story)

    buffer.seek(0)

    return buffer


def build_summary_pdf(data, date_label):
    settings = WorkshopSettings.get_solo()

    buffer = BytesIO()

    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        leftMargin=16 * mm,
        rightMargin=16 * mm,
        topMargin=16 * mm,
        bottomMargin=16 * mm,
    )

    styles = getSampleStyleSheet()

    story = [
        Paragraph(
            f'{settings.name}',
            styles['Heading1'],
        ),
        Paragraph(
            f'Financial Summary — {date_label}',
            styles['Normal'],
        ),
        Spacer(1, 12),
    ]

    metrics = [
        [
            'Jobs',
            str(data['jobs']),
        ],
        [
            'Materials',
            money(
                data['materials'],
                settings.currency,
            ),
        ],
        [
            'Labour',
            money(
                data['labour'],
                settings.currency,
            ),
        ],
        [
            'Revenue',
            money(
                data['revenue'],
                settings.currency,
            ),
        ],
        [
            'Approved Expenses',
            money(
                data['expenses'],
                settings.currency,
            ),
        ],
        [
            'Net Profit / Loss',
            money(
                data['net'],
                settings.currency,
            ),
        ],
    ]

    table = Table(
        metrics,
        colWidths=[
            90 * mm,
            80 * mm,
        ],
    )

    table.setStyle(
        TableStyle(
            [
                (
                    'BACKGROUND',
                    (0, 0),
                    (0, -1),
                    CHARCOAL,
                ),
                (
                    'TEXTCOLOR',
                    (0, 0),
                    (0, -1),
                    colors.white,
                ),
                (
                    'FONTNAME',
                    (0, 0),
                    (-1, -1),
                    'Helvetica-Bold',
                ),
                (
                    'ALIGN',
                    (1, 0),
                    (1, -1),
                    'RIGHT',
                ),
                (
                    'GRID',
                    (0, 0),
                    (-1, -1),
                    .5,
                    colors.HexColor('#DDDDDD'),
                ),
                (
                    'TOPPADDING',
                    (0, 0),
                    (-1, -1),
                    9,
                ),
                (
                    'BOTTOMPADDING',
                    (0, 0),
                    (-1, -1),
                    9,
                ),
            ]
        )
    )

    story += [table]

    doc.build(story)

    buffer.seek(0)

    return buffer