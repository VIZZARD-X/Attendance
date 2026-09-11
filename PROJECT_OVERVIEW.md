# Attendance App - Project Overview & Technical Architecture

## 1. The Core Idea & Purpose
The **Attendance App** was built to solve two major problems in modern educational institutions: the immense time wasted on manual roll calls, and the rampant issue of "proxy attendance" (students marking their absent friends as present). 

It is a comprehensive, full-stack educational technology platform that modernizes attendance tracking. Instead of calling out names, teachers can initiate an automated session. The system uses a combination of dynamic QR codes, geospatial/temporal data, and AI-powered facial verification to guarantee that the student marking attendance is actually physically present in the classroom.

Beyond just collecting data, the app acts as an early warning system. It processes the raw attendance data into rich, actionable analytics, automatically identifying students who are at risk of falling behind and flagging suspicious activity for the teacher to review.

---

## 2. The Real-World Workflow
1. **Starting a Session:** A teacher walks into a classroom, opens the app, and taps "Start Session". The app projects a dynamic, time-sensitive QR code on the smartboard.
2. **Marking Attendance:** Students open the app on their own smartphones and scan the projected QR code. 
3. **Identity Verification (Anti-Proxy):** Upon scanning, the student may be prompted to take a quick selfie. The app uses AI facial recognition (Google GenAI/OpenCV) against a reference image to verify the student's identity. 
4. **Data Processing:** The backend verifies the timestamp, the identity, and the class enrollment. It logs the attendance and simultaneously runs anomaly detection (e.g., checking if the same device marked multiple students).
5. **Analytics & Interventions:** After class, the teacher can open their Analytics Dashboard to see who is consistently absent, review any "Integrity Flags" (e.g., "Burst Marking" or "Session Collision"), and send automated interventions to struggling students.

---

## 3. Technical Stack

### **Backend (Django / Python)**
* **Framework:** Django 5.2.7 with Django REST Framework (DRF)
* **Authentication:** JSON Web Tokens (JWT) via `djangorestframework-simplejwt`
* **Database:** SQLite (default/Azure App Service configured) with `dj-database-url` for environment variable configuration.
* **Server & Deployment:** Gunicorn server, WhiteNoise for static file serving. Deployed to Microsoft Azure App Service (Linux containers).
* **AI & Image Processing:** Integrates `google-genai`, `opencv-python-headless`, and `Pillow` for AI-based face verification and image validation to ensure attendance integrity.
* **Other Tools:** `django-cors-headers`, `python-dotenv`, `qrcode`.

### **Frontend (Flutter / Dart)**
* **Framework:** Flutter (Stable channel)
* **Platforms:** Web, Android (APK), and potentially iOS.
* **Architecture:** Communicates entirely via the REST API using bearer tokens.
* **Styling & UI:** Custom design system (`AnalyticsTheme`) featuring Material 3, rich micro-animations, teal/blue hero gradients, and responsive layouts.

### **CI/CD pipeline (GitHub Actions)**
* **`main_presence.yml`:** The primary deployment workflow. It checks out the code, builds the Flutter Web app, bundles it into the backend's `flutter_web` directory, and deploys the entire package to Azure Web Apps. 
* **Startup Script (`startup.sh`):** Executes automatically in Azure to run database migrations (`manage.py migrate`), seed initial data, and spin up the Gunicorn server.

---

## 3. Core Features & Capabilities

### User Roles & Authentication
The system supports three distinct roles, each with tightly scoped permissions:
* **Administrators:** Full system control. Can manage classes, semesters, users, and overall system statistics.
* **Teachers:** Can create/manage their classes, initiate attendance sessions, verify attendance, and monitor class analytics.
* **Students:** Can enroll in classes (via class codes), mark their attendance, and view their personal attendance history and forecasts.

### Automated Attendance Workflows
* **QR Code Sessions:** Teachers can launch an active session which generates a unique, time-stamped QR code payload.
* **Image Verification:** To prevent proxy attendance, the system supports uploading reference images and uses OpenCV/Google GenAI to verify student presence.
* **Offline Sync:** Handles edge cases where internet connectivity is poor (`sync_offline_pattern`, `sync_offline_session`).

### Advanced Analytics & Dashboards
Recently introduced in the `v1/analytics/` API suite, the app provides deep insights into attendance trends:

**For Teachers:**
* **Cohort Overview:** High-level metrics across all classes or filtered by a specific class/term.
* **At-Risk Triage:** Automatically identifies and ranks students who are falling behind required attendance thresholds (e.g., < 75%).
* **Integrity Flags:** An automated advisory system that flags suspicious activity. Flags include:
  * *Session Collision* (student marked present in two places)
  * *Burst Marking* (multiple students marked simultaneously, indicating a proxy cluster)
  * *Low Verification Score* (AI image mismatch)
  * *Late Outliers* & *Cohort Drops*.
  Teachers can manually resolve or dismiss these flags with notes.

**For Students:**
* **Personal Overview:** Current attendance percentage and standings.
* **Interactive Calendar:** A month-by-month calendar view showing exactly when they were present or absent.
* **Forecast Simulator:** An interactive slider that lets students simulate how future absences will impact their final attendance percentage, helping them plan ahead.

### Intervention & Communication
* **Announcements:** Teachers and admins can broadcast announcements to classes.
* **Intervention Logs:** Tracks automated or manual interventions sent to at-risk students, monitoring baseline vs. follow-up attendance to gauge if the intervention successfully improved their attendance.

---

## 4. Database Schema (Key Models)

* **`User` / `StudentProfile`:** Custom user model extending Django auth, tracking roles and basic info.
* **`AcademicTerm`:** Groups classes into timeframes (e.g., Fall 2026) with required attendance thresholds.
* **`Class` & `Enrollment`:** Maps which students belong to which teacher's courses.
* **`AttendanceSession`:** A specific lecture occurrence (bound to a Class, Teacher, and Start/End time).
* **`AttendanceRecord`:** The junction table recording a specific student's status (Present, Absent, Pending) for a specific Session.
* **`AttendanceFlag`:** Records suspicious activity detected during a session, tied to a specific student and severity level.
* **`InterventionLog`:** Maps announcements to students to measure the effectiveness of warnings.

---

## 5. Deployment Architecture

1. **Routing Strategy:** Django acts as the absolute catch-all. 
   * Requests to `/api/v1/*` are routed to Django REST Framework views.
   * Requests to `/admin/*` go to the Django Admin panel.
   * All other requests (e.g., `/`, `/teacher`, `/student`) are caught by a regex in `urls.py` which serves the compiled Flutter web files (`index.html`) from the `flutter_web` directory.
2. **Database Resilience:** On Azure, the SQLite database is mapped to a persistent volume mount (`/home/db.sqlite3`) ensuring data isn't wiped between deployments.
3. **Seeding:** A `seed.py` script exists to quickly spin up demo environments with mock administrators, teachers, students, and simulated attendance sessions.
