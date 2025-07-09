# Konkur AI Study Planner (برنامه ریز هوشمند کنکور)

## Project Overview

The Iranian National University Entrance Exam (Konkur) is a highly competitive and challenging milestone for students in Iran. Preparing for it requires meticulous planning, consistent effort, and adaptive strategies. This responsive Flutter application, the **Konkur AI Study Planner (برنامه ریز هوشمند کنکور)**, aims to simplify and optimize this preparation journey.

This app is specifically designed for students tackling the Konkur, with an initial focus on the **Math & Physics track**. It leverages the power of the Gemini AI to create dynamic, personalized, and optimized study plans. These plans are based on the official subject weighting (`بودجه بندی`), the user's self-assessed strengths in various topics, and the crucial factor of time remaining until the exam.

A key feature is its **local-first approach**: all user data, including study progress and personal notes, is stored securely on the device using an SQLite database. This ensures user privacy, allows for full offline access to study plans and materials, and makes the app reliable even without a constant internet connection. To further aid students, the app incorporates features like push notifications for task reminders and an interactive timer to help manage study sessions effectively.

## Core Features

- **AI-Powered Adaptive Planning:** Leverages the Gemini API to generate intelligent daily study schedules. The AI not only considers the official syllabus and user-defined strengths but also *adapts to user performance feedback over time*, making plans progressively more effective.
- **Official Syllabus Integration:** Incorporates the detailed `بودجه بندی` (topic weighting and question distribution) for the Math & Physics Konkur track. This ensures comprehensive coverage and prioritization of high-impact subjects.
- **Personalized Strengths Assessment:** Users can identify and select topics where they feel more confident. This crucial input allows the AI to allocate appropriate time to strengthen weaker areas while maintaining proficiency in others.
- **Dynamic & Flexible Daily Schedule:** Presents the study plan in a clear, intuitive, and easy-to-follow daily format. The schedule can be regenerated or adjusted based on changing needs or unexpected interruptions.
- **Interactive Task Tracking with Feedback Loop:** Each study task is equipped with an interactive timer. Upon completion of a study session, users can provide qualitative feedback (e.g., "understood concepts well but struggled with specific problem types"). This feedback is fed back to the AI, creating a continuous improvement loop for future plan generation.
- **Smart Task Reminders:** Utilizes local push notifications to remind users of upcoming study sessions (start and end times), helping them stay consistent and disciplined with their schedule.
- **Local-First Data Storage:** All user data, including syllabus information, selected strengths, generated plans, and feedback, is stored and managed securely on the device's local SQLite database. This guarantees data privacy, enables full offline functionality, and ensures the app is always accessible.
- **Responsive User Interface:** Designed with Flutter to provide a seamless and consistent user experience across various screen sizes, initially targeting Android and iOS mobile platforms.

## Getting Started

Follow these instructions to set up and run the Konkur AI Study Planner project on your local machine for development and testing purposes.

### Prerequisites

Before you begin, ensure you have the following installed:

*   **Flutter SDK:** Make sure you have the latest stable version of Flutter installed. You can find installation instructions on the [official Flutter website](https://docs.flutter.dev/get-started/install).
*   **Git:** You'll need Git to clone the repository. Download it from [git-scm.com](https://git-scm.com/downloads).
*   **IDE (Optional but Recommended):** An IDE like Visual Studio Code (with the Flutter extension) or Android Studio will provide the best development experience.

### Installation & Setup

1.  **Clone the Repository:**
    Open your terminal or command prompt and run the following command to clone the project:
    ```bash
    git clone https://github.com/your-username/konkur_planner.git
    ```
    (Replace `https://github.com/your-username/konkur_planner.git` with the actual repository URL.)

2.  **Navigate to Project Directory:**
    Change into the project's root directory:
    ```bash
    cd konkur_planner
    ```

3.  **Install Dependencies:**
    Fetch all the required Flutter packages by running:
    ```bash
    flutter pub get
    ```
    This command reads the `pubspec.yaml` file and downloads the necessary libraries.

4.  **Configure API Key for Gemini Service:**
    This project utilizes the Gemini API for its AI planning features. You will need to:
    *   Obtain an API key from [Google AI Studio](https://aistudio.google.com/app/apikey).
    *   Locate the `GeminiService` (likely in `lib/services/gemini_service.dart`).
    *   Insert your API key where indicated within the service. For development, you might temporarily hardcode it, but for production, consider more secure methods like environment variables loaded via a package (e.g., `flutter_dotenv`).
    *   **Important:** Be careful not to commit your actual API key to version control if you hardcode it.

5.  **Run the Application:**
    *   Ensure you have an emulator running or a physical device connected.
    *   You can check connected devices by running: `flutter devices`
    *   To start the application, run:
        ```bash
        flutter run
        ```
    This will build and install the app on your selected device/emulator.

You should now have the Konkur AI Study Planner running!

## How to Use the Konkur AI Study Planner

This guide walks you through the typical workflow of using the Konkur AI Study Planner to prepare for your exams.

1.  **Initial Setup - Define Your Strengths:**
    *   When you first launch the app, or whenever you want to update your profile, navigate to the **"درس های من (My Subjects / Strengths Profile)"** screen.
    *   Here, you'll find a list of all Konkur topics. Go through this list and check off the topics in which you feel most confident or have a strong understanding.
    *   This step is crucial as it helps the AI tailor the study plan to your specific needs, focusing more on areas where you might need improvement.

2.  **Generate Your Study Plan:**
    *   Go to the **"هوش مصنوعی (AI Agent / Smart Assistant)"** screen.
    *   Interact with the AI assistant by typing your request in Persian. You'll need to provide key information such as:
        *   Your target exam date or the number of days you have to study.
        *   Any specific subjects or topics you want to focus on or deprioritize.
        *   Example: "یک برنامه درسی برای ۱۰ روز آینده با تمرکز بر فیزیک و حسابان برایم آماده کن." (Prepare a 10-day study plan for me with a focus on Physics and Calculus.)
        *   Another example: "تا کنکور ۳ ماه وقت دارم، روزی ۴ ساعت میتونم درس بخونم، برام برنامه بریز." (I have 3 months until Konkur, I can study 4 hours a day, create a plan for me.)
    *   The AI will process your request along with your defined strengths and the official syllabus weighting, then generate a structured study plan.

3.  **Follow Your Daily Schedule:**
    *   Access your personalized schedule on the **"برنامه من (My Plan / Daily Schedule)"** screen.
    *   This screen will display your tasks for the current day and upcoming days, including the subject, topic, type of activity (e.g., review, test-taking), and allocated time.
    *   For each task, click the **"Start Study" (شروع مطالعه)** button. This will activate an in-app timer for the duration specified for that task. Focus on the task until the timer is up.

4.  **Provide Feedback (Crucial for Adaptation!):**
    *   When the timer for a study session finishes (or if you manually complete a task), a dialog box will appear.
    *   Enter a brief description of your session. Be honest and specific. For example:
        *   "مبحث مشتق را خوب فهمیدم اما در تست‌های بهینه‌سازی مشکل دارم." (I understood the topic of derivatives well, but I have trouble with optimization tests.)
        *   "تست های فصل حرکت شناسی رو خیلی خوب زدم." (I did very well on the kinematics chapter tests.)
        *   "نیاز به مرور بیشتر در مبحث دینامیک دارم." (I need more review on the dynamics topic.)
    *   This feedback is saved and used by the AI to refine and improve future study plans, making them more adapted to your learning pace and challenges.

5.  **Review Syllabus Weighting (Optional but Recommended):**
    *   At any time, you can visit the **"بودجه بندی (Syllabus Breakdown / Topic Weighting)"** screen.
    *   This screen shows the official Konkur syllabus and the number of questions per topic. Use this information to understand why certain topics might be prioritized in your plan and to make strategic decisions about your study focus.

6.  **Iterate and Adapt:**
    *   Your study needs may change. You might have a school exam, feel you need more time on a particular subject, or finish some topics ahead of schedule.
    *   Return to the **"هوش مصنوعی (AI Agent)"** screen at any time to request adjustments to your plan. For example: "برنامه دو روز آینده را برای مرور فیزیک تنظیم کن." (Adjust the plan for the next two days to review Physics.)
    *   The AI will take your new requests and your accumulated feedback into account to generate an updated plan.

By consistently following your plan, providing honest feedback, and interacting with the AI for adjustments, you can create a highly personalized and effective study routine for the Konkur exam.

## Application Pages (Screens)

The application's user experience is centered around four main pages:

1.  **هوش مصنوعی (AI Agent / Smart Assistant):**
    *   This is the primary interface for interacting with the AI planning engine.
    *   Users can converse with the Gemini-powered agent using natural language (Persian).
    *   **Key interactions include:**
        *   Generating an initial study plan by specifying the exam date, available study days, and any specific focus areas. (e.g., "برام یه برنامه ۱٠ روزه تا کنکور بریز با تمرکز روی ریاضیات گسسته")
        *   Requesting updates or regeneration of the plan based on new constraints or progress. (e.g., "برنامه فردا رو سبک تر کن، امتحان مدرسه دارم")
        *   Providing ad-hoc feedback or asking for study tips.
    *   The AI's output (the structured study plan) is processed by the app and saved to the local database, subsequently updating the "My Plan" screen.

2.  **بودجه بندی (Syllabus Breakdown / Topic Weighting):**
    *   A reference screen providing a clear, read-only view of the official Konkur syllabus for the Math & Physics track.
    *   It details subjects (e.g., "حسابان", "هندسه", "فیزیک پایه دهم") and their constituent topics, along with the official number of questions allocated to each topic in the exam.
    *   This screen serves as a crucial tool for strategic planning, allowing users to understand topic importance and make informed decisions when identifying their strengths on the "My Subjects" page.
    *   The syllabus data is pre-populated in the local database for offline access.

3.  **درس های من (My Subjects / Strengths Profile):**
    *   An interactive screen where users define their academic strengths.
    *   It presents a checklist of all topics from the syllabus. Users select the topics they feel most confident or proficient in.
    *   This self-assessment is a critical input for the AI agent. The AI uses this profile to tailor the study plan, potentially allocating less introductory time to strong topics and more review or advanced practice, while ensuring weaker areas receive adequate attention.
    *   This selection is typically made during initial setup but can be revisited and updated by the user at any time to reflect their evolving skills. Selections are saved locally.

4.  **برنامه من (My Plan / Daily Schedule):**
    *   This screen is the user's daily guide, displaying the AI-generated study plan in an organized format (e.g., a daily list, timeline, or calendar view).
    *   Each task item in the plan clearly states the subject, topic, type of activity (e.g., "مرور" - Review, "تست" - Test-taking), and allocated time.
    *   **Interactive elements include:**
        *   A **"Start Study" (شروع مطالعه) button** (visualized perhaps as a Play icon) next to each task, which activates an in-app countdown timer for the allocated duration.
        *   Visual indication of task progress (e.g., pending, in-progress, completed).
        *   Upon timer completion (or manual marking of completion), a dialog prompts the user for brief qualitative feedback on their session (e.g., "مبحث تابع رو کامل یاد گرفتم ولی نیاز به تست بیشتر دارم"). This feedback is crucial for the AI's adaptive learning.
    *   Users can see upcoming tasks and review completed ones, helping them stay on track and motivated.

## Project Structure

The project adheres to a standard Flutter application structure, ensuring maintainability and scalability. Key directories and files are organized as follows:

- **`lib/`**: This is the heart of the application, containing all Dart source code.
    - **`main.dart`**: The main entry point that initializes and runs the Flutter application. It now uses `MaterialApp.router` and delegates routing logic to `lib/routing/app_router.dart`.
    - **`routing/`**: Contains all navigation and routing logic for the application.
        - **`app_router.dart`**: Defines the `GoRouter` configuration, including routes, sub-routes, and `ShellRoute` for persistent UI elements like the bottom navigation bar.
    - **`constants/`**: Stores application-wide constants, such as API keys (though sensitive keys should be managed via secure means like environment variables in actual builds), UI theme colors, string literals, or fixed configuration values (e.g., `app_constants.dart`).
    - **`database/`**: Contains code related to local data persistence, primarily `database_helper.dart` which manages SQLite database creation, schema, and CRUD (Create, Read, Update, Delete) operations.
    - **`models/`**: Defines the data structures or classes that represent the application's entities, such as `study_task.dart`, `topic.dart`, and `user_selection.dart`. These models dictate how data is structured and handled within the app.
    - **`providers/`**: Manages application state using the `provider` package. Files like `app_data_provider.dart` would hold and expose application-wide state, allowing different parts of the UI to react to data changes.
    - **`screens/`**: Contains the Dart files for each distinct UI screen or page of the application, such as `ai_agent_screen.dart`, `my_plan_screen.dart`, `my_subjects_screen.dart`, and `syllabus_breakdown_screen.dart`. These are now navigated to using `go_router`.
    - **`services/`**: Houses services that interact with external systems or provide background functionalities. This includes `gemini_service.dart` for communications with the Gemini API and `notification_service.dart` for managing local push notifications.
    - **`widgets/`** (Assumed, common practice): Although not explicitly listed in the initial file tree, a `widgets/` directory is typically present for reusable UI components shared across multiple screens. The `MainShell` widget, which includes the `BottomNavigationBar` and is used by `go_router`, could be considered part of this or within the `routing` directory.
    - **`utils/`** (If present): For utility functions, helper classes, or extensions that don't fit into other specific categories (e.g., date formatters, input validators).

- **`assets/`**: Stores static assets used by the application.
    - **`assets/fonts/`**: Contains custom font files like IRANSans and IRANYekan.
    - **`assets/images/`**: Contains images and icons, such as logos and illustrations used within the app.

- **`android/`**: Contains Android-specific project files and configurations for building the Android version of the app.
- **`ios/`**: Contains iOS-specific project files and configurations (Xcode project) for building the iOS version of the app.
- **`web/`**: Contains files for building the web version of the app, including `index.html` and manifest files.
- **`windows/`**, **`linux/`**, **`macos/`**: Platform-specific files for building desktop versions of the application, if targeted.

- **`test/`** (Assumed, standard practice): This directory would contain unit, widget, and integration tests for the application, helping to ensure code quality and correctness.

- **`pubspec.yaml`**: The project's manifest file. It declares project metadata, dependencies (packages like `provider`, `sqflite`, `http`), and asset declarations (fonts, images).
- **`pubspec.lock`**: Automatically generated file that records the exact versions of all dependencies used in the project, ensuring consistent builds.
- **`analysis_options.yaml`**: Configures the Dart static analyzer and linter to enforce code style and catch potential issues.
- **`README.md`**: This file – providing an overview, setup instructions, and documentation for the project.
- **`.gitignore`**: Specifies intentionally untracked files that Git should ignore (e.g., build outputs, IDE configuration files).

## AI Agent & Adaptive Planning Logic

The effectiveness of the Konkur AI Study Planner stems from a smart interaction loop between the user, the app, and the Gemini AI. Here's how it works:

1.  **Comprehensive Input Gathering:** Before querying the AI, the application compiles a rich set of information:
    *   **Syllabus Data:** The complete list of official Konkur topics and their respective question counts (importance).
    *   **User's Strength Profile:** The topics the user has self-identified as strengths.
    *   **Historical Performance & Feedback:** Crucially, a summary or relevant snippets of `user_feedback` from previously completed study tasks (e.g., "had trouble with integration by parts," "aced the geometry quiz").
    *   **User's Current Request:** The specific instruction or query from the user, such as "create a 7-day plan" or "help me prepare for my physics midterm focusing on mechanics."

2.  **Intelligent Prompt Construction (Prompt Engineering):**
    *   The application doesn't just send raw data. It constructs a detailed and carefully worded prompt for the Gemini API.
    *   This prompt skillfully weaves together the syllabus information, user strengths, past feedback, and the current request into a coherent set of instructions for the AI.
    *   For instance, the prompt might include: "...Given the user is strong in 'Trigonometry' but previously reported 'difficulty with optimization problems in Calculus' and now requests 'a 3-day intensive plan for Calculus', please generate a schedule that allocates significant review and practice for optimization, while still scheduling appropriate revision for other Calculus sections and brief reviews for Trigonometry..."

3.  **AI as a Structured Data Generator (Not a Direct Controller):**
    *   The Gemini AI's role is to act as an intelligent "reasoning engine." It processes the complex prompt and generates a *structured study plan*.
    *   The app specifies the format it expects this plan in, typically a JSON (JavaScript Object Notation) structure. This JSON will detail the daily tasks, topics, timings, and types of study (review, test-taking).
    *   It's important to understand that the AI **does not directly interact with the app's database or control UI elements.** It provides the *data and recommendations* in the requested structured format.

4.  **Local Data Processing and Integration:**
    *   The Flutter application receives the structured JSON response from the Gemini API.
    *   It then parses this JSON data, validates it, and translates it into actionable information for the local SQLite database.
    *   New tasks are added to the `study_tasks` table, or existing ones might be updated based on the AI's new plan.

5.  **Dynamic UI Updates and Notifications:**
    *   Once the local database is updated with the new or revised plan, the changes are automatically reflected in the "برنامه من (My Plan)" screen.
    *   The application's notification service (`NotificationService`) then schedules local push reminders for all new "pending" tasks in the updated plan, ensuring the user stays informed and on track.

This continuous cycle of input -> AI processing -> structured output -> app integration -> user feedback -> refined input allows the study plans to become increasingly personalized and effective over time.

## Navigation

The application uses the `go_router` package for declarative routing. The main navigation structure is defined in `lib/routing/app_router.dart`.

- **Main Screens:** The four main screens (AI Agent, Syllabus, My Subjects, My Plan) are implemented as top-level routes within a `ShellRoute`.
- **`ShellRoute`:** This is used to maintain the `BottomNavigationBar` across the main screens. The `MainShell` widget in `lib/routing/app_router.dart` builds the `Scaffold` with the `BottomNavigationBar` and displays the current child route.
- **Adding New Routes:**
    - To add a new top-level screen accessible from the `BottomNavigationBar`, add a new `GoRoute` to the `routes` list within the `ShellRoute` in `app_router.dart`. Update the `MainShell`'s `BottomNavigationBar` and its `_calculateSelectedIndex` and `_onItemTapped` methods accordingly.
    - To add a sub-route (e.g., a detail screen navigated from one of the main screens), add it as a sub-route to one of the existing `GoRoute` definitions. For example:
      ```dart
      GoRoute(
        path: '/my-plan',
        name: 'myPlan',
        builder: (context, state) => const MyPlanScreen(),
        routes: [
          GoRoute(
            path: 'task-details/:taskId', // Example: /my-plan/task-details/123
            name: 'taskDetails',
            builder: (context, state) {
              final taskId = state.pathParameters['taskId']!;
              return TaskDetailsScreen(taskId: taskId);
            },
          ),
        ],
      ),
      ```
- **Navigating:** Use `GoRouter.of(context).go('/path')` or `GoRouter.of(context).goNamed('routeName')` for navigation. For passing parameters, refer to the `go_router` documentation.

## Local Database (SQLite) Schema

We will structure our local database with the following tables:

**`topics`**

| Column           | Type         | Description                        |
|:-----------------|:-------------|:-----------------------------------|
| `id`             | INTEGER (PK) | Unique ID for the topic            |
| `name`           | TEXT         | Name of the topic (e.g., "مثلثات") |
| `subject`        | TEXT         | Parent subject (e.g., "حسابان")    |
| `question_count` | INTEGER      | Number of questions in Konkur      |

**`user_selections`**

| Column      | Type         | Description                                          |
|:------------|:-------------|:-----------------------------------------------------|
| `topic_id`  | INTEGER (FK) | Foreign key referencing `topics.id`                  |
| `is_strong` | INTEGER      | 1 if the user selected it as a strength, 0 otherwise |

**`study_tasks`**

| Column          | Type            | Description                                             |
|:----------------|:----------------|:--------------------------------------------------------|
| `id`            | INTEGER (PK)    | Unique ID for the task                                  |
| `topic_id`      | INTEGER (FK)    | The topic this task is for                              |
| `task_date`     | TEXT            | The date of the task (e.g., "2024-07-15")               |
| `start_time`    | TEXT            | The start time (e.g., "09:00")                          |
| `end_time`      | TEXT            | The end time (e.g., "11:30")                            |
| `task_type`     | TEXT            | "مرور" (Review) or "تست" (Test-taking)                  |
| `status`        | TEXT            | "pending", "in_progress", "completed"                   |
| `user_feedback` | TEXT (NULLABLE) | User's description of the session after the timer ends. |

## Contributing

Contributions are welcome and greatly appreciated! If you'd like to contribute to the Konkur AI Study Planner project, please follow these guidelines:

1.  **Fork the Repository:**
    Start by forking the main repository to your own GitHub account.

2.  **Create a Branch:**
    Create a new branch in your forked repository for your feature or bug fix. Use a descriptive branch name (e.g., `feature/add-dark-mode` or `fix/timer-bug`).
    ```bash
    git checkout -b feature/your-feature-name
    ```

3.  **Make Your Changes:**
    Implement your feature or fix the bug. Ensure your code adheres to the existing project structure and coding style (refer to `analysis_options.yaml` for linting rules).

4.  **Test Your Changes:**
    If you're adding a new feature or fixing a bug, please try to add relevant tests (unit or widget tests) in the `test/` directory to ensure your changes work as expected and don't break existing functionality. Run all tests to confirm.
    ```bash
    flutter test
    ```

5.  **Commit Your Changes:**
    Commit your changes with a clear and concise commit message. Follow conventional commit message formats if possible (e.g., `feat: Add user profile editing` or `fix: Correct calculation in study timer`).
    ```bash
    git add .
    git commit -m "feat: Describe your feature or fix"
    ```

6.  **Push to Your Branch:**
    Push your changes to your forked repository.
    ```bash
    git push origin feature/your-feature-name
    ```

7.  **Submit a Pull Request (PR):**
    Open a pull request from your branch in your forked repository to the `main` branch of the original Konkur AI Study Planner repository.
    *   Provide a clear title and description for your PR, explaining the changes you've made and why.
    *   If your PR addresses an existing issue, please link to it.

### Coding Style

*   Please follow the Dart effective coding guidelines.
*   Ensure your code is well-formatted (you can use `dart format .`).
*   Adhere to the linting rules defined in `analysis_options.yaml`.

### Questions or Suggestions?

If you have any questions, suggestions, or want to discuss a potential contribution, feel free to open an issue on the GitHub repository.

Thank you for considering contributing to this project!

## License

This project is intended to be open source. Please choose an appropriate license (e.g., MIT, Apache 2.0) and add a `LICENSE` file to the repository.

For now, you can consider it under the **MIT License**. A formal `LICENSE` file should be added.
(Placeholder: Copyright (c) 2024 Konkur AI Study Planner Contributors)
