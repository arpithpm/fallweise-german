import asyncio
import json
import logging

from dotenv import load_dotenv
from livekit.agents import (
    Agent,
    AgentServer,
    AgentSession,
    JobContext,
    TurnHandlingOptions,
    cli,
    inference,
    room_io,
)

logger = logging.getLogger("fallweise-agent")
load_dotenv(".env.local")


class TutorTransport(Agent):
    """Media transport only; the web curriculum owns teaching and grading."""

    def __init__(self) -> None:
        super().__init__(
            instructions="Speak only text supplied by the Fallweise lesson engine.",
            llm=None,
        )


async def publish(ctx: JobContext, payload: dict) -> None:
    await ctx.room.local_participant.publish_data(
        json.dumps(payload), reliable=True, topic="fallweise.agent"
    )


server = AgentServer()


def build_session() -> AgentSession:
    return AgentSession(
        stt=inference.STT(
            model="deepgram/nova-3",
            language="de",
            extra_kwargs={
                "endpointing": 300,
                "interim_results": True,
                "utterance_end": True,
            },
        ),
        tts=inference.TTS(
            model="cartesia/sonic-3.5",
            voice="9626c31c-bec5-4cca-baa8-f8ba9e84c8bc",
            language="de",
        ),
        llm=None,
        turn_handling=TurnHandlingOptions(
            turn_detection="vad",
            endpointing={"min_delay": 0.4, "max_delay": 1.2},
            interruption={"enabled": True},
        ),
    )


@server.rtc_session(agent_name="fallweise-livekit-agent")
async def fallweise_agent(ctx: JobContext):
    ctx.log_context_fields = {"room": ctx.room.name}
    background_tasks: set[asyncio.Task] = set()

    def spawn(coroutine) -> None:
        task = asyncio.create_task(coroutine)
        background_tasks.add(task)
        task.add_done_callback(background_tasks.discard)

    session = build_session()

    async def speak(command: dict) -> None:
        command_id = command.get("id")
        text = command.get("text", "").strip()
        if not command_id or not text:
            return
        await publish(ctx, {"type": "speech_started", "id": command_id})
        try:
            handle = session.say(text, allow_interruptions=True, add_to_chat_ctx=False)
            await handle.wait_for_playout()
            await publish(
                ctx,
                {
                    "type": "speech_finished",
                    "id": command_id,
                    "interrupted": handle.interrupted,
                },
            )
        except Exception:
            logger.exception("TTS command failed")
            await publish(ctx, {"type": "speech_failed", "id": command_id})

    @ctx.room.on("data_received")
    def on_data_received(packet):
        if packet.topic != "fallweise.lesson":
            return
        try:
            command = json.loads(packet.data.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return
        logger.info(
            "lesson command received", extra={"command_type": command.get("type")}
        )
        if command.get("type") == "speak":
            spawn(speak(command))
        elif command.get("type") == "hello":
            spawn(publish(ctx, {"type": "ready"}))
        elif command.get("type") == "interrupt":
            spawn(session.interrupt(force=True))

    @session.on("user_input_transcribed")
    def on_transcript(event):
        logger.info(
            "user input transcribed",
            extra={
                "is_final": event.is_final,
                "language": event.language,
                "transcript": event.transcript,
            },
        )
        if event.is_final and event.transcript.strip():
            spawn(
                publish(
                    ctx,
                    {"type": "transcript", "text": event.transcript.strip()},
                )
            )

    @session.on("agent_state_changed")
    def on_agent_state(event):
        spawn(publish(ctx, {"type": "agent_state", "state": event.new_state}))

    @session.on("user_state_changed")
    def on_user_state(event):
        logger.info("user state changed", extra={"state": event.new_state})
        spawn(publish(ctx, {"type": "user_state", "state": event.new_state}))

    # Connect explicitly so the browser can see this participant before model
    # initialization. AgentSession detects the existing connection and reuses it.
    await ctx.connect()
    logger.info("connected to room")
    await session.start(
        agent=TutorTransport(),
        room=ctx.room,
        room_options=room_io.RoomOptions(close_on_disconnect=True),
    )
    await publish(ctx, {"type": "ready"})
    logger.info("agent ready")


if __name__ == "__main__":
    cli.run_app(server)
