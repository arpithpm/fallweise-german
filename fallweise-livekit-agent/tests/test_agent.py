from agent import TutorTransport, build_session


def test_transport_has_no_llm() -> None:
    agent = TutorTransport()
    assert agent.llm is None


def test_transport_instructions_forbid_improvisation() -> None:
    agent = TutorTransport()
    assert "only text supplied" in str(agent.instructions).lower()


async def test_session_uses_german_stt_and_vad_endpointing() -> None:
    session = build_session()
    assert "nova-3" in session.stt.model
    assert session.stt._opts.language == "de"
    assert session.options.turn_handling["turn_detection"] == "vad"
    assert session.options.turn_handling["endpointing"]["max_delay"] == 1.2
