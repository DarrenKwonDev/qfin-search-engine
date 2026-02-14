# 논문 메타
- 제목: Explainable Patterns in Cryptocurrency Microstructure
- 저자: Bartosz Bieganowski, Robert Ślepaczuk
- arXiv ID: 2602.00776
- 공개일: 2026-01-31
- 요약 근거: abstract 기반 요약 (PDF 저장 성공, 본문 자동 파싱은 미실시)

# 문제 정의 및 배경
암호화폐 선물 시장에서 자산이 달라도 미시시장구조 신호가 일관되게 작동하는지, 그리고 실제 체결 비용을 반영해도 전략이 유지되는지를 검증한다.

# 핵심 가설/아이디어
order book/trade 기반 피처의 예측 구조는 자산별로 크게 다르지 않으며, 해석 가능한 ML(SHAP 포함)로 단기 방향성 신호를 안정적으로 포착할 수 있다는 가설이다.

# 데이터
- 데이터 소스: Binance Futures perpetual contract 호가/체결 데이터
- 기간: 2022-01-01 ~ 2025-10-12
- 샘플 구성: BTC, LTC, ETC, ENJ, ROSE (시총/유동성 스펙트럼)
- 피처: order flow imbalance, spread, trade/LOB 엔지니어드 피처

# 방법론
- 모델/알고리즘: CatBoost + direction-aware GMADL objective
- 학습/검증 절차: 시계열 교차검증(time-series CV)
- 하이퍼파라미터: abstract에 상세값 미공개
- 실행 평가: top-of-book taker, fixed-depth maker 백테스트를 분리 평가

# 실험/결과
- 자산 간 피처 중요도와 SHAP dependency shape가 유사하게 유지됨
- flash crash 구간에서 taker/maker 성과 차이가 커지며 adverse selection 리스크를 실증
- 단기 알파 피처 라이브러리의 이식 가능성(portability)을 제시

# 재현성
- 코드/데이터 공개 여부: abstract 기준 명시 없음
- 구현 난이도: 중간 (1초 단위 LOB 데이터 처리 인프라 필요)
- 필요한 의존성: CatBoost, SHAP, 시계열 CV, 체결비용/슬리피지 모델

# 한계 및 실패 사례
- 거래소/상품 구조(Binance perpetual)에 결과가 부분적으로 종속될 수 있음
- 극단 변동 구간에서 maker 전략이 adverse selection에 취약
- 신호 강도 대비 거래비용 민감도가 높아 운영 난이도 존재

# 확장 아이디어
- 상위 핵심 피처만 남긴 단순 룰 기반 베이스라인(테스트 엔진 검증용) 구축
- 솔라나/DEX 체결 데이터로 피처 이식성 비교
- 이벤트 구간(뉴스/급변동) 전용 레짐 스위칭 로직 추가
