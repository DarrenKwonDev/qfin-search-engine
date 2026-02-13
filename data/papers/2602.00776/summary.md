# 논문 메타
- 제목: Explainable Patterns in Cryptocurrency Microstructure
- 저자: Bartosz Bieganowski, Robert Ślepaczuk
- arXiv ID: 2602.00776
- 공개일: 2026-01-31
- 요약 근거: abstract 기반 요약 (PDF는 저장했지만 본문 섹션 파싱은 미실시)

# 문제 정의 및 배경
암호화폐 시장의 limit order book(LOB) 신호가 자산별로 얼마나 일관되게 작동하는지, 그리고 실제 거래 가능한 패턴인지 검증한다.

# 핵심 가설/아이디어
공학적으로 설계한 미시구조 피처(주문흐름 불균형, 스프레드 등)는 자산이 달라도 유사한 예측 구조를 가지며, 해석 가능한 모델로 단기 수익률 신호를 포착할 수 있다는 가설이다.

# 데이터
- 소스: Binance Futures perpetual contract의 호가/체결 데이터
- 기간: 2022-01-01 ~ 2025-10-12
- 샘플 구성: BTC, LTC, ETC, ENJ, ROSE 등 시가총액 스펙트럼이 다른 자산
- 피처: 주문장/체결 기반 engineered features, SHAP 해석 대상 피처

# 방법론
- 모델: CatBoost 파이프라인 + direction-aware GMADL objective
- 검증: 시계열 교차검증(time-series cross validation)
- 전략 평가: 보수적 top-of-book taker 백테스트와 fixed-depth maker 백테스트

# 실험/결과
- 자산 간 피처 중요도 순위와 SHAP 의존 형태가 상당히 안정적으로 관측됨
- 플래시 크래시 강건성 점검에서 taker/maker 성과 차이가 미시구조 이론(역선택 위험)과 정합적
- 단기 수익률 예측에 이식 가능한(portable) 피처 라이브러리 가능성을 제시

# 재현성
- 코드/데이터 공개 여부: abstract에서 직접 명시 없음
- 구현 난이도: 중간 (1초 빈도 LOB 데이터와 피처 엔지니어링 필요)
- 필요한 의존성: CatBoost, SHAP 분석 도구, 시계열 CV 및 체결비용 반영 백테스트 환경

# 한계 및 실패 사례
- 암호화폐 선물 특정 시장 구조에 의존할 수 있음
- 고빈도 데이터 인프라와 거래비용 모델링에 민감
- 플래시 크래시 구간에서 전략별 성과 분화가 커 일반화 시 주의 필요

# 확장 아이디어
- 초심자용 단순화: SHAP 상위 3~5개 피처만 사용한 선형/로지스틱 베이스라인 추가
- 주식/선물 등 타 자산군으로 피처 이식성 검증
- 거래비용/슬리피지 시나리오를 단계별로 늘려 현실성 평가
