from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt


OUT = "BaoCao_MyMiniCloud.docx"


def field(paragraph, instruction):
    run = paragraph.add_run()
    begin = OxmlElement("w:fldChar")
    begin.set(qn("w:fldCharType"), "begin")
    instr = OxmlElement("w:instrText")
    instr.set(qn("xml:space"), "preserve")
    instr.text = instruction
    separate = OxmlElement("w:fldChar")
    separate.set(qn("w:fldCharType"), "separate")
    text = OxmlElement("w:t")
    text.text = "1"
    end = OxmlElement("w:fldChar")
    end.set(qn("w:fldCharType"), "end")
    run._r.extend([begin, instr, separate, text, end])


def add_placeholder(doc, text):
    p = doc.add_paragraph()
    p.add_run(f"[INSERT IMAGE: {text}]").bold = True
    return p


def add_table(doc, headers, rows):
    table = doc.add_table(rows=1, cols=len(headers))
    table.style = "Table Grid"
    for cell, value in zip(table.rows[0].cells, headers):
        cell.text = value
    for row in rows:
        cells = table.add_row().cells
        for cell, value in zip(cells, row):
            cell.text = value
    return table


doc = Document()
section = doc.sections[0]
section.top_margin = Inches(0.8)
section.bottom_margin = Inches(0.8)
section.left_margin = Inches(1.0)
section.right_margin = Inches(1.0)

normal = doc.styles["Normal"]
normal.font.name = "Times New Roman"
normal._element.rPr.rFonts.set(qn("w:eastAsia"), "Times New Roman")
normal.font.size = Pt(13)
normal.paragraph_format.line_spacing = 1.5

for style_name in ["Title", "Heading 1", "Heading 2", "Heading 3"]:
    style = doc.styles[style_name]
    style.font.name = "Times New Roman"
    style._element.rPr.rFonts.set(qn("w:eastAsia"), "Times New Roman")
    if style_name == "Heading 1":
        style.font.size = Pt(16)
    elif style_name == "Heading 2":
        style.font.size = Pt(14)

footer = section.footer.paragraphs[0]
footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
footer.add_run("Page ")
field(footer, "PAGE")

title = doc.add_paragraph()
title.alignment = WD_ALIGN_PARAGRAPH.CENTER
title.add_run("CLOUD COMPUTING\n").bold = True
title.add_run("MINICLOUD SYSTEM SIMULATION\n").bold = True
title.add_run("\nFinal Project Report").bold = True
doc.add_paragraph("\nProject: Nhom16miniclouddemo")
doc.add_paragraph("Students: Nguyễn Đức Anh; Bùi Trọng Khang; Trần Vinh Quí")
doc.add_paragraph("Student IDs and class: [TO BE COMPLETED]")
doc.add_paragraph("Supervisor: Bùi Quy Anh")
doc.add_paragraph("Docker Hub: wasabi4816")
doc.add_paragraph("Submission date: [TO BE COMPLETED]")
doc.add_page_break()

doc.add_heading("Table of Contents", level=1)
field(doc.add_paragraph(), 'TOC \\o "1-3" \\h \\z \\u')
doc.add_paragraph("Update fields in Microsoft Word after opening this document.")
doc.add_heading("List of Figures and Tables", level=1)
doc.add_paragraph("Figure 1. MiniCloud network topology — [INSERT GENERATED DIAGRAM]")
doc.add_paragraph("Figure 2. Request and monitoring flows — [INSERT GENERATED DIAGRAM]")
doc.add_paragraph("Table 1. Service, port and cloud-service mapping")
doc.add_page_break()

doc.add_heading("Chapter 1. Introduction and Objectives", level=1)
doc.add_paragraph(
    "Cloud computing provides on-demand computing, networking, storage and managed "
    "platform services. AWS, Microsoft Azure and Google Cloud Platform expose these "
    "capabilities through virtual machines, managed databases, object storage, identity "
    "services, load balancers and observability platforms. This project implements a "
    "small local simulation so that the relationships between those cloud roles can be "
    "understood before deployment to an Ubuntu Amazon EC2 instance."
)
doc.add_heading("1.1 Project objectives", level=2)
doc.add_paragraph(
    "The objectives are to deploy nine independent server roles with Docker Compose, "
    "connect them through the cloud-net bridge network, protect the application endpoint "
    "with Keycloak-issued JWTs, persist state with volumes, and provide repeatable tests. "
    "The attached course brief focuses on EC2; therefore, EC2 provisioning, Security "
    "Groups and SSH are included as the deployment stage of this broader simulation."
)
doc.add_heading("1.2 Role of each server and cloud analogy", level=2)
add_table(doc, ["Role", "Implementation", "Cloud analogy"], [
    ["Web", "Nginx static frontend and /blog/", "Object-backed static hosting / CDN origin"],
    ["Application", "Flask /hello and JWT-protected /secure", "Container or managed application service"],
    ["Database", "MariaDB with initialization SQL", "Amazon RDS for MariaDB"],
    ["Authentication", "Keycloak realm and demo user", "Amazon Cognito / IAM identity"],
    ["Object storage", "MinIO API and Console", "Amazon S3"],
    ["DNS", "Bind9 cloud.local zone", "Amazon Route 53 private hosted zone"],
    ["Monitoring", "Prometheus and node-exporter", "CloudWatch metrics pipeline"],
    ["Dashboard", "Grafana provisioned from Prometheus", "Managed observability dashboard"],
    ["Gateway/LB", "Nginx upstreams and path routing", "Application Load Balancer / API Gateway"],
])

doc.add_heading("Chapter 2. Architecture and Diagrams", level=1)
doc.add_paragraph(
    "All services join cloud-net (172.28.0.0/24). Fixed addresses make the laboratory "
    "topology easy to inspect, while Docker service names remain the preferred mechanism "
    "for application-to-application discovery."
)
add_table(doc, ["Service", "Container", "Host port", "Internal port/IP"], [
    ["Web", "minicloud-web", "8080", "80 / 172.28.0.11"],
    ["Application", "minicloud-app", "8085", "8081 / 172.28.0.12"],
    ["Database", "minicloud-db", "3306", "3306 / 172.28.0.14"],
    ["Keycloak", "minicloud-keycloak", "8081", "8080 / 172.28.0.13"],
    ["MinIO", "minicloud-minio", "9000, 9001", "9000, 9001 / 172.28.0.15"],
    ["Bind9", "minicloud-dns", "1053 TCP/UDP", "53 / 172.28.0.10"],
    ["Prometheus", "minicloud-prometheus", "9090", "9090 / 172.28.0.17"],
    ["Node exporter", "minicloud-node-exporter", "9100", "9100 / 172.28.0.16"],
    ["Grafana", "minicloud-grafana", "3000", "3000 / 172.28.0.18"],
    ["Proxy", "minicloud-proxy", "80", "80 / 172.28.0.19"],
])
add_placeholder(doc, "cloud-net topology showing all nine server roles and ports")
add_placeholder(doc, "Client -> proxy -> web/application -> database/auth/storage request flow")
doc.add_paragraph(
    "The monitoring flow is node-exporter -> Prometheus -> Grafana. Prometheus also "
    "scrapes the application metrics endpoint. The Nginx gateway exposes the frontend "
    "at / and routes /api/web/ and /api/app/ to separate upstream blocks."
)

doc.add_heading("Chapter 3. Configuration and Dockerfiles", level=1)
doc.add_heading("3.1 Compose orchestration", level=2)
doc.add_paragraph(
    "docker-compose.yml defines one container per role, the cloud-net bridge, named "
    "volumes for MariaDB, Keycloak, MinIO, Bind9 cache, Prometheus and Grafana, and "
    "restart: unless-stopped. Health-based depends_on conditions delay the application "
    "and gateway until their dependencies are ready."
)
doc.add_heading("3.2 Custom images and configurations", level=2)
doc.add_paragraph(
    "The web Dockerfile packages Nginx and the static frontend into the custom image "
    "wasabi4816/myminicloud-web:latest. The application Dockerfile installs pinned "
    "Flask, PyJWT, requests and Gunicorn dependencies. Keycloak imports "
    "minicloud-realm.json, which defines the minicloud-app public client and student "
    "laboratory user. MariaDB executes 01-schema.sql on first initialization."
)
doc.add_paragraph(
    "Bind9 loads named.conf and db.cloud.local. Prometheus uses explicit targets for "
    "itself, node-exporter and the application. Grafana provisions the Prometheus "
    "datasource and a target-status dashboard. The proxy configuration defines web_backend "
    "and app_backend upstreams and uses proxy_pass with trailing slashes to strip route "
    "prefixes."
)

doc.add_heading("Chapter 4. Demonstration and Testing", level=1)
doc.add_paragraph(
    "The repository contains test_all.sh and test_all.ps1. They check the frontend, "
    "blog, /hello, missing-token rejection, Keycloak token issuance, authenticated "
    "/secure, MariaDB, MinIO, Bind9, Prometheus, node-exporter, Grafana and the gateway."
)
doc.add_heading("4.1 Verification status", level=2)
doc.add_paragraph(
    "At report generation time, static configuration and Python syntax were checked. "
    "The local Docker Desktop integration run subsequently completed successfully: "
    "all fourteen PowerShell checks passed, including JWT-protected /secure and the "
    "cloud.local DNS lookup. EC2 deployment, Docker Hub publication, screenshots and "
    "performance measurements remain user-supplied evidence."
)
add_table(doc, ["Check", "Required command/action", "Evidence status"], [
    ["Build", "docker compose build", "PASS: custom images built"],
    ["Startup", "docker compose up -d; docker compose ps", "PASS: services running"],
    ["HTTP services", "curl/Invoke-WebRequest endpoints", "PASS"],
    ["JWT", "Keycloak token then /secure", "PASS"],
    ["Database", "docker exec ... SHOW DATABASES", "PASS"],
    ["DNS", "container nslookup cloud.local zone", "PASS"],
    ["EC2", "Ubuntu instance, SG, SSH, public IP", "USER ACTION REQUIRED"],
])
add_placeholder(doc, "terminal showing docker compose ps with all services healthy")
add_placeholder(doc, "curl /hello, 401 /secure, valid JWT /secure and database output")
add_placeholder(doc, "Keycloak login/token, MinIO Console, Prometheus targets and Grafana dashboard")
add_placeholder(doc, "EC2 console, Security Group, SSH session and public-IP endpoint")

doc.add_heading("Chapter 5. Evaluation and Analysis", level=1)
doc.add_heading("5.1 Strengths", level=2)
doc.add_paragraph(
    "The design is reproducible, self-contained and close to real cloud separation of "
    "concerns. Healthchecks make startup ordering explicit, named volumes preserve state, "
    "and the test scripts reduce manual verification errors. The same Compose definition "
    "can be transferred to Ubuntu EC2."
)
doc.add_heading("5.2 Difficulties and limitations", level=2)
doc.add_paragraph(
    "The observed environment limitation is the stopped Docker Desktop Linux engine, "
    "which prevents image builds and integration testing. The design is also single-host, "
    "uses fixed bridge IPs, has no high availability, and uses development credentials "
    "and HTTP rather than production TLS. Keycloak realm import is intended for a fresh "
    "laboratory volume and should be replaced by managed identity and secret rotation in production."
)
doc.add_heading("5.3 Future work", level=2)
doc.add_paragraph(
    "Future improvements include Kubernetes deployments and Services, CI/CD image scanning "
    "and promotion, HTTPS/TLS, Terraform infrastructure as code, autoscaling, managed "
    "databases and object storage, centralized logs, backups, network policies and least-"
    "privilege IAM."
)

doc.add_heading("Appendix A. User action checklist", level=1)
doc.add_paragraph(
    "The student must start Docker Desktop, run the build/start/test commands, save real "
    "outputs under evidence/, complete MSSN/class data, create and secure EC2, push the "
    "custom image, take screenshots, record the video URL, and replace every placeholder "
    "before submission."
)
doc.add_paragraph("Docker Hub link: https://hub.docker.com/r/wasabi4816/myminicloud-web")
doc.add_paragraph("Video link: [INSERT VIDEO DEMO LINK]")

doc.add_heading("Appendix B. Evidence and configuration", level=1)
doc.add_paragraph(
    "The configuration source files are in the project root and service directories. "
    "After runtime execution, include docker compose config output, docker compose ps, "
    "test_all output, endpoint responses, DNS output and EC2 deployment output in evidence/."
)

doc.add_heading("References", level=1)
references = [
    "Docker Documentation. https://docs.docker.com/",
    "Nginx Documentation. https://nginx.org/en/docs/",
    "Keycloak Documentation. https://www.keycloak.org/documentation",
    "MinIO Documentation. https://min.io/docs/minio/linux/index.html",
    "Prometheus Documentation. https://prometheus.io/docs/",
    "Grafana Documentation. https://grafana.com/docs/grafana/latest/",
    "BIND 9 Administrator Reference Manual. https://bind9.readthedocs.io/",
    "Amazon EC2 User Guide. https://docs.aws.amazon.com/ec2/",
]
for reference in references:
    doc.add_paragraph(reference, style="List Bullet")

doc.save(OUT)
print(OUT)
