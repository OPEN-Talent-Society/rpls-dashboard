from fastapi.testclient import TestClient

import main


client = TestClient(main.app)


def test_summary_headlines():
    res = client.get("/api/summary")
    assert res.status_code == 200
    data = res.json()
    assert "headline_metrics" in data
    assert data["headline_metrics"]["total_employment"] is not None


def test_salary_endpoints_return_numbers():
    occ = client.get("/api/salaries/occupation")
    state = client.get("/api/salaries/state")
    assert occ.status_code == 200
    assert state.status_code == 200
    occ_data = occ.json()["data"]
    state_data = state.json()["data"]
    assert len(occ_data) > 0
    assert len(state_data) > 0
    assert isinstance(occ_data[0]["salary"], (int, float))
    assert isinstance(state_data[0]["salary"], (int, float))


def test_sector_spotlight():
    res = client.get("/api/sector-spotlight")
    assert res.status_code == 200
    data = res.json()
    assert len(data["winners"]) > 0
    assert len(data["losers"]) > 0


def test_hiring_quadrant():
    res = client.get("/api/hiring-quadrant")
    assert res.status_code == 200
    data = res.json()
    assert data["month"]
    assert len(data["sectors"]) > 0
