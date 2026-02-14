# 논문 메타
- 제목: Forecasting High Frequency Order Flow Imbalance
- 저자: Aditya Nittur Anantha, Shashi Jain
- arXiv ID: 2408.03594
- 공개일: 2024-08-07
- 요약 근거: abstract 기반 요약 (PDF 저장 성공, 본문 자동 파싱은 미실시)

# 문제 정의 및 배경
체결/주문 이벤트의 비대칭이 단기 가격 변화를 유발하는데, OFI(Order Flow Imbalance)를 얼마나 안정적으로 추정/예측할 수 있는지가 단기 전략의 핵심이다.

# 핵심 가설/아이디어
bid/ask 주문흐름의 지연 의존성을 Hawkes 프로세스로 모델링하면 OFI의 근미래 분포를 더 잘 예측할 수 있고, 이 예측력이 전략 신호의 품질을 개선할 수 있다는 가설이다.

# 데이터
- 데이터 소스: 인도 NSE 틱 데이터
- 기간: abstract에 상세 기간 미기재
- 샘플 구성: 고빈도 bid/ask 주문 이벤트 시계열
- 피처: OFI, Hawkes 기반 강도(intensity) 추정치

# 방법론
- 모델/알고리즘: Hawkes process (Sum-of-Exponentials kernel 포함)
- 학습/검증 절차: OFI 분포 예측 성능으로 다중 모델 비교
- 하이퍼파라미터: 커널 구조는 명시, 세부 추정 설정은 abstract에 제한적

# 실험/결과
- OFI 예측 프레임워크를 제시하고 모델 간 비교 절차를 체계화
- Sum-of-Exponentials Hawkes가 비교군 대비 가장 우수한 예측 성능 보고
- 실전에서는 OFI 방향/강도를 단기 진입 필터로 쓰는 근거를 제공

# 재현성
- 코드/데이터 공개 여부: abstract 기준 명시 없음
- 구현 난이도: 중상 (Hawkes 추정과 고빈도 이벤트 처리 필요)
- 필요한 의존성: 틱 데이터 파이프라인, Hawkes 라이브러리 또는 자체 추정기

# 한계 및 실패 사례
- OFI 예측 정확도가 직접적인 수익률 개선으로 항상 이어지지는 않음
- 거래비용, 큐 포지션, 지연(latency) 요소를 별도 반영해야 실전성 확보 가능
- 단일 시장 데이터 기반이라 자산/거래소 일반화 검증이 필요

# 확장 아이디어
- Hawkes 대신 단순 EMA 기반 OFI nowcast와 성능/복잡도 비교
- 체결 데이터만 사용 가능한 환경에서는 trade-sign imbalance 대체 지표 테스트
- 추정된 OFI 분포의 tail 구간만 트리거로 쓰는 저빈도 실행 룰 설계
