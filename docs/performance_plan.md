### 2. 성능 최적화 계획 제안

이 프로젝트의 CPU 및 메모리 사용량을 최소화하기 위한 구체적인 설계를 implementation_plan.md에 상세히 작성했습니다.

• 중점 최적화 사항:
    1. CGWindowListCopyWindowInfo 중복 호출(최대 3회)을 단 1회 호출 후 데이터 전달 구조로 개선하여 창 스캔 시 CPU 부하를 최대 60% 이상 절감합니다.
    2. 종료된 앱의 AXObserver를 정리할 때 RunLoop Source를 명시적으로 해제(CFRunLoopRemoveSource)하여 메모리 누수와 자원 낭비를 차단합니다.
    3. 실시간 미리보기 동작 시 불필요한 포커싱 신호가 중복 발생하지 않도록 캐싱 로직을 강화합니다.
