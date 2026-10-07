# 서울 경계 데이터

`extension/seoul-boundary.js`는 다음 GeoJSON에서 `code: 11`인 서울특별시 Polygon의 좌표를 추출한 파일입니다. 좌표를 단순화하거나 사각형으로 대체하지 않았습니다.

- 원본: https://github.com/southkorea/southkorea-maps/blob/master/kostat/2018/json/skorea-provinces-2018-geo.json
- 데이터: KOSTAT 2018, 변환·배포: southkorea/southkorea-maps / Team POPONG
- 출처 및 이용 조건: https://github.com/southkorea/southkorea-maps#copyright-and-license (KOSTAT: Free to share or remix; POPONG: CC BY 4.0)
- 추출일: 2026-10-08

2018년 경계 데이터이므로 이후 경계 조정이나 기기 위치 오차에 따라 경계 부근의 판별이 다를 수 있습니다. 위치 좌표는 메모리에서만 판별하며 저장하거나 외부 지오코딩 서비스로 전송하지 않습니다.
