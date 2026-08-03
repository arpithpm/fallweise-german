from agent import TutorTransport


def test_transport_has_no_llm() -> None:
    agent = TutorTransport()
    assert agent.llm is None


def test_transport_instructions_forbid_improvisation() -> None:
    agent = TutorTransport()
    assert "only text supplied" in str(agent.instructions).lower()
