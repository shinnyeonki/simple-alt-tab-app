# Simple Alt Tab App (Option-Tab Switcher)
![](assets/sample.mp4)
`simple-alt-tab-app`은 macOS 환경에서 작동하는 lightweight 단축키 기반 창 전환기입니다. 시스템 기본 단축키(Cmd+Tab)를 대체하거나 보완하여, 사용자가 `Option + Tab` 및 `Option + Shift + Tab`을 통해 활성화된 창 간에 빠르고 직관적으로 전환할 수 있도록 돕습니다.

---

## 🏗️ Core Architecture & File Responsibilities

이 프로젝트는 총 3개의 핵심 Swift 소스 파일로 구성되어 있으며, 각각 명확하고 독립적인 역할을 담당합니다.

### 1. [AppDelegate.swift](file:///Users/shinnk/source/project/apple/simple-alt-tab-app/simple-alt-tab-app/AppDelegate.swift)
**역할: 어플리케이션의 생명주기 관리 및 권한 제어**
- **Lifecycle & MenuBar**: 앱 실행 시 백그라운드 에이전트 모드로 동작하며, 상태 표시줄(Menu Bar) 아이콘과 설정 메뉴(창 크기 설정, 윈도우 탐색 범위, 창 활성화 기능 토글 등)를 생성합니다.
- **Permission Checking**: macOS의 보안 프레임워크인 `Accessibility (손쉬운 사용)` 및 `Screen & System Audio Recording (화면 기록)` 권한 획득 여부를 감지하고, 권한이 없을 경우 가이드 Alert를 표시하며 권한 획득 전까지 타이머를 돌려 상태를 주기적으로 폴링합니다.
- **Event Dispatching**: 모든 권한이 허용되면 전역 키보드 이벤트를 캡처하는 `EventMonitor`를 구동합니다.

### 2. [SwitcherLogic.swift](file:///Users/shinnk/source/project/apple/simple-alt-tab-app/simple-alt-tab-app/SwitcherLogic.swift)
**역할: 창 정보 탐색, 단축키 처리 및 UI 렌더링 (핵심 비즈니스 로직)**
- **EventMonitor**: `CGEvent.tapCreate` 기반의 Session Event Tap을 사용하여 전역 키보드 입력(`Option+Tab`, `Option+Shift+Tab`, `Option` 키 뗌 등)을 비동기적으로 감지하고, 메인 스레드에 이벤트를 즉각 위임합니다.
- **SwitcherManager**: 창 전환을 조율하는 싱글톤 매니저입니다.
  - `getWindows()`를 통해 활성화된 앱의 표준 창(Standard Window) 정보를 AX(Accessibility) API 및 CGWindowList API를 결합하여 수집합니다.
  - 탐색 범위(현재 데스크톱 vs 전체 데스크톱)에 맞춰 윈도우 목록을 가공하고, MRU(최근 사용 순서)에 따라 정렬합니다.
  - 사용자가 선택한 타겟 창으로 포커스를 전환(`executeSwitch`)합니다.
- **SwitcherWindow & SwitcherView**: 화면 중앙에 띄울 투명 `NSPanel` 윈도우와 해당 창 목록을 커스텀 드로잉하는 `NSView`입니다. 창이 0개인 예외 상황(영문 안내 메시지 렌더링)부터 1개 및 n개까지의 레이아웃과 Hover/Click 이벤트를 직접 렌더링합니다.

### 3. [Settings.swift](file:///Users/shinnk/source/project/apple/simple-alt-tab-app/simple-alt-tab-app/Settings.swift)
**역할: 앱 설정(Preferences) 관리 및 데이터 모델 정의**
- **Preferences**: `UserDefaults`에 저장되는 사용자 설정(스위처 UI 크기, 라이브 윈도우 프리뷰 활성화 여부, 윈도우 탐색 범위)을 래핑하여 Get/Set 인터페이스를 일관성 있게 제공합니다.
- **Data Models**:
  - `UISize`: Small, Medium, Large 크기에 따른 행(Row) 높이, 아이콘 크기, 제목/본문 폰트 크기 등의 수치 상수를 보관합니다.
  - `WindowScope`: 창 스캔 범위를 결정하는 `allDesktops`와 `currentDesktop` 모드를 열거형으로 정의합니다.

---

## 🛠️ Build & Development

프로젝트를 빌드하려면 다음 셸 스크립트를 실행합니다:
```bash
./build.sh
```
빌드가 성공하면 `dist/simple-alt-tab-app.app` 경로에 애플리케이션 번들이 생성되고 로직 서명(Ad-hoc Code Sign)이 완료됩니다.
