# 논문 메타
- 제목: Interpretable Hypothesis-Driven Trading:A Rigorous Walk-Forward Validation Framework for Market Microstructure Signals
- 저자: Gagan Deep, Akash Deep, William Lamptey
- arXiv ID: 2512.12924
- 공개일: 2025-12-15
- 요약 근거: abstract 기반 요약 (PDF 저장 성공, 본문 자동 파싱은 미실시)

# 문제 정의 및 배경
미시시장구조 기반 신호는 백테스트에서 과적합되기 쉬워, 실제 운용 가능성을 보장하는 검증 프레임워크가 필요하다.

# 핵심 가설/아이디어
복잡한 블랙박스 모델보다 해석 가능한 가설 주도(hypothesis-driven) 신호 설계와 엄격한 walk-forward 검증이 실제 전이성(out-of-sample robustness)을 높인다는 가설이다.

# 데이터
- 데이터 소스: 미국 주식 100종목의 일봉 OHLCV 기반 신호
- 기간: 2015-01-01 ~ 2024-12-31
- 샘플 구성: 34개 독립 OOS 테스트 구간으로 롤링 검증
- 피처: market microstructure 가설에서 도출한 5개 신호 패턴

# 방법론
- 모델/알고리즘: 해석 가능한 hypothesis-driven 신호 + RL 결합
- 학습/검증 절차: 정보집합 분리(lookahead 방지) + rolling walk-forward OOS 검증
- 하이퍼파라미터: 거래비용/포지션 제약 포함, 세부값은 본문/코드 참조

# 실험/결과
- 연환산 수익률 0.55%, Sharpe 0.33, 최대낙폭 -2.76%, beta 0.058 보고
- 고변동 구간(2020-2024)에서는 양(+) 성과, 안정 구간(2015-2019)에서는 저조한 성과
- 총괄 p-value 0.34로 통계적 유의성이 낮음을 공개해 검증 정직성을 강조

# 재현성
- 코드/데이터 공개 여부: 오픈소스 구현 제공을 명시
- 구현 난이도: 중간 (검증 파이프라인은 명확, 데이터 준비가 핵심)
- 필요한 의존성: 시계열 분할/검증 도구, 거래비용/포지션 제약 반영 백테스트 엔진

# 한계 및 실패 사례
- 구체적 성능 수치와 데이터 디테일은 본문 의존도가 높음
- 신호 정의가 단순할수록 시장 레짐 변화 대응력이 약할 수 있음

# 확장 아이디어
- 테스트 전용으로 2~3개 단순 신호(OFI, spread, microprice)만 사용한 미니 프레임워크 구현
- walk-forward 윈도 길이별 민감도 분석 자동화
- 실패 케이스를 feature/state 단위로 로깅해 전략 디버깅 파이프라인 강화
