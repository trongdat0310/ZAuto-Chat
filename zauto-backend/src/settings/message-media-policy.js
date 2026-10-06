// ========================================
// MESSAGE MEDIA DISPLAY POLICY
//
// Pure helpers:
// - khong IO
// - khong cache
// - de unit test
// ========================================

export function isPhotoConversationEvent(
  message
) {
  const raw =
    message?.data?.msgType ??
    message?.msgType;

  const type =
    String(
      raw ?? ""
    )
      .trim()
      .toLowerCase();


  return (
    type ===
      "chat.photo" ||
    Number(raw) ===
      32
  );
}


export function isVoiceConversationEvent(
  message
) {
  const raw =
    message?.data?.msgType ??
    message?.msgType;

  const type =
    String(
      raw ?? ""
    )
      .trim()
      .toLowerCase();


  return (
    type ===
      "chat.voice" ||
    type ===
      "chat.voice.msg" ||
    type ===
      "chat.audio" ||
    Number(raw) ===
      31
  );
}


export function shouldDisplayConversationEvent(
  settings,
  message
) {
  const safeSettings =
    settings &&
    typeof settings ===
      "object"
      ? settings
      : {};


  if (
    safeSettings.showImages ===
      false &&
    isPhotoConversationEvent(
      message
    )
  ) {

    return false;
  }


  if (
    safeSettings.showVoiceMessages ===
      false &&
    isVoiceConversationEvent(
      message
    )
  ) {

    return false;
  }


  return true;
}
