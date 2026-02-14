# 논문 메타
- 제목: Order-Flow Filtration and Directional Association with Short-Horizon Returns
- 저자: Aditya Nittur Anantha, Shashi Jain, Prithwish Maiti
- arXiv ID: 2507.22712
- 공개일: 2025-07-30
- 요약 근거: abstract 기반 요약 (PDF 저장 성공, 본문 자동 파싱은 미실시)

# 문제 정의 및 배경
초단기 수익률 예측에서 주문흐름(order flow)에 잡음성 주문이 많아지면 OBI(Order Book Imbalance) 신호가 약해진다. 이 논문은 "어떤 체결/주문 이벤트를 걸러내면 방향성 신호가 더 좋아지는가"를 다룬다.

# 핵심 가설/아이디어
모든 주문흐름을 그대로 쓰는 것보다, 체결된 주문의 부모 주문(parent order)에 구조적 필터를 적용하면 OBI와 단기 수익률의 연관성이 강화될 수 있다는 가설이다.

# 데이터
- 데이터 소스: 인도 NSE(BankNifty 선물) 틱 단위 데이터
- 기간: abstract에 상세 기간 미기재
- 샘플 구성: 주문 수명(order lifetime), 수정 횟수/타이밍, 체결 이벤트 기반 분해
- 피처: OBI, 필터링된 OBI, 단기 수익률 레짐

# 방법론
- 모델/알고리즘: 구조적 필터링 + 상관/레짐 연관성 분석 + Hawkes event-time 진단
- 학습/검증 절차: 3단계 진단 사다리(동시 상관 -> 이산 레짐 선형 연관 -> Hawkes excitation)
- 하이퍼파라미터: abstract 기준 상세값 미공개

# 실험/결과
- 전체 주문흐름을 단순 필터링한 경우 개선은 제한적
- 체결된 주문의 부모 주문에 필터를 건 OBI는 방향성 연관성이 일관되게 강화
- 실무적으로는 "잡음 제거 후 OBI"가 원본 OBI 대비 더 유용한 신호일 가능성을 제시

# 재현성
- 코드/데이터 공개 여부: abstract 기준 명시 없음
- 구현 난이도: 중간 (틱 데이터 정합/이벤트 분해 필요)
- 필요한 의존성: 체결/주문 이벤트 파서, OBI 계산기, Hawkes 추정 도구

# 한계 및 실패 사례
- 특정 시장(BankNifty)과 미시구조에 결과가 의존할 수 있음
- 필터링 설계가 과도하면 신호 지연 또는 정보 손실 가능
- 전략 성능(PnL)보다는 신호 연관성 진단 중심이라 실전 전환 시 추가 검증 필요

# 확장 아이디어
- 체결 데이터만 있을 때는 간소화된 trade-imbalance 필터 버전으로 변환
- 이벤트 타임 바(event-time bars)와 결합해 신호 안정성 비교
- 거래비용/슬리피지 반영한 초단기 룰 기반 백테스트로 바로 연결
