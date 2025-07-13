This project is a Konkur AI Study Planner, a responsive Flutter application designed to help Iranian students prepare for the national university entrance exam, with a focus on the Math & Physics track. It uses the Gemini AI to generate personalized and adaptive study plans based on the official subject weighting, user-assessed strengths, and time remaining until the exam.

A key aspect of the application is its local-first approach, storing all user data, including study progress and notes, on the device in an SQLite database. This ensures user privacy and allows for full offline access to the application. The app also includes features like push notifications for task reminders, an interactive timer to help students manage their study sessions effectively, full Persian (Farsi) localization with a Jalali date picker, and a native splash screen for a smooth startup experience.

### Core Features:

* **AI-Powered Adaptive Planning:** The app uses the Gemini API to generate intelligent daily study schedules that adapt to user performance feedback over time.
* **Official Syllabus Integration:** It incorporates the detailed topic weighting and question distribution for the Math & Physics Konkur track.
* **Personalized Strengths Assessment:** Users can identify their strengths, which allows the AI to create a tailored study plan.
* **Interactive Task Tracking with Feedback Loop:** Each study task has a timer, and upon completion, users can provide feedback that is used to refine future study plans.
* **Smart Task Reminders:** The app uses local push notifications to remind users of upcoming study sessions.

### Application Pages:

1.  **AI Agent / Smart Assistant:** This is the main interface for interacting with the AI to generate and update study plans.
2.  **Syllabus Breakdown / Topic Weighting:** This screen provides a read-only view of the official Konkur syllabus.
3.  **My Subjects / Strengths Profile:** Here, users can define their academic strengths.
4.  **My Plan / Daily Schedule:** This page displays the AI-generated study plan in a daily format, with interactive elements like a study timer.