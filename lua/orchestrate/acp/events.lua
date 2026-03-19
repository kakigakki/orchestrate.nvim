local Events = {
  USER_SUBMIT = "user_submit",
  CONNECTED = "connected",
  ASSISTANT_STREAM_START = "assistant_stream_start",
  ASSISTANT_STREAM_DELTA = "assistant_stream_delta",
  ASSISTANT_STREAM_END = "assistant_stream_end",
  -- Content block types
  CONTENT_BLOCK_START = "content_block_start",
  CONTENT_BLOCK_DELTA = "content_block_delta",
  CONTENT_BLOCK_END = "content_block_end",
  -- Tool events
  TOOL_USE_START = "tool_use_start",
  TOOL_USE_END = "tool_use_end",
  TOOL_RESULT = "tool_result",
  -- Other events
  TODO_UPDATED = "todo_updated",
  APPROVAL_REQUESTED = "approval_requested",
  REVIEW_READY = "review_ready",
  SESSION_UPDATED = "session_updated",
  ERROR = "error",
}

return Events
