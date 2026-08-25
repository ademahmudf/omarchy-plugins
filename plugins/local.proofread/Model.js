// Proofreader AI Engine for Omarchy

var PROMPTS = {
  fix: "You are an expert editor and proofreader. Fix all grammatical mistakes, spelling errors, awkward phrasing, and punctuation in the provided text while keeping its exact original meaning and tone. Return ONLY the final corrected text without quotes, explanation, or conversational filler.",
  professional: "You are a professional business writer. Rewrite the provided text so it is polished, clear, confident, and professional for work communication (emails, Slack messages, documentation, PR reviews). Return ONLY the final rewritten text without quotes, explanation, or conversational filler.",
  concise: "You are an expert editor. Make the provided text concise, impactful, and direct by removing unnecessary filler words while keeping all important information. Return ONLY the final shortened text without quotes, explanation, or conversational filler.",
  casual: "Rewrite the provided text in a friendly, warm, casual, and natural conversational tone. Return ONLY the final text without quotes, explanation, or conversational filler.",
  translate: "Translate the provided text into natural, fluent, idiomatically correct English. If it is already in English, refine and polish it. Return ONLY the final English translation without quotes, explanation, or conversational filler."
};

var DEFAULT_SETTINGS = {
  provider: "gemini", // "gemini" | "groq" | "openai" | "ollama"
  apiKey: "",
  geminiModel: "gemini-1.5-flash",
  openaiModel: "gpt-4o-mini",
  groqModel: "llama-3.3-70b-versatile",
  ollamaEndpoint: "http://localhost:11434/v1",
  ollamaModel: "llama3"
};

function getSystemPrompt(mode) {
  return PROMPTS[mode] || PROMPTS.fix;
}

function cleanAiOutput(text) {
  if (!text) return "";
  var clean = String(text).trim();
  // Strip leading/trailing quotes if the model wrapped the response in quotes
  if ((clean.startsWith('"') && clean.endsWith('"')) || (clean.startsWith('“') && clean.endsWith('”'))) {
    clean = clean.substring(1, clean.length - 1).trim();
  }
  // Strip markdown code block if model wrapped in ```
  if (clean.startsWith("```") && clean.endsWith("```")) {
    var lines = clean.split("\n");
    if (lines.length > 2) {
      clean = lines.slice(1, lines.length - 1).join("\n").trim();
    }
  }
  return clean;
}

function parseSettingsJson(jsonText) {
  if (!jsonText || String(jsonText).trim() === "") return Object.assign({}, DEFAULT_SETTINGS);
  try {
    var data = JSON.parse(jsonText);
    return Object.assign({}, DEFAULT_SETTINGS, data);
  } catch (e) {
    return Object.assign({}, DEFAULT_SETTINGS);
  }
}

function buildGeminiRequest(apiKey, model, systemPrompt, userText) {
  var url = "https://generativelanguage.googleapis.com/v1beta/models/" + encodeURIComponent(model || "gemini-1.5-flash") + ":generateContent?key=" + encodeURIComponent(apiKey || "");
  var payload = {
    contents: [
      {
        role: "user",
        parts: [{ text: userText }]
      }
    ],
    systemInstruction: {
      parts: [{ text: systemPrompt }]
    },
    generationConfig: {
      temperature: 0.3,
      topP: 0.95
    }
  };
  return {
    url: url,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload)
  };
}

function buildOpenAiCompatibleRequest(endpoint, apiKey, model, systemPrompt, userText) {
  var url = endpoint.replace(/\/+$/, "") + "/chat/completions";
  var headers = { "Content-Type": "application/json" };
  if (apiKey) {
    headers["Authorization"] = "Bearer " + apiKey;
  }
  var payload = {
    model: model,
    messages: [
      { role: "system", content: systemPrompt },
      { role: "user", content: userText }
    ],
    temperature: 0.3
  };
  return {
    url: url,
    headers: headers,
    body: JSON.stringify(payload)
  };
}

function parseGeminiResponse(responseText) {
  try {
    var data = JSON.parse(responseText);
    if (data.candidates && data.candidates[0] && data.candidates[0].content && data.candidates[0].content.parts) {
      return cleanAiOutput(data.candidates[0].content.parts[0].text);
    }
    if (data.error) {
      return "Error: " + (data.error.message || JSON.stringify(data.error));
    }
    return "Error: Unexpected response format from Gemini";
  } catch (e) {
    return "Error parsing response: " + e.message;
  }
}

function parseOpenAiResponse(responseText) {
  try {
    var data = JSON.parse(responseText);
    if (data.choices && data.choices[0] && data.choices[0].message) {
      return cleanAiOutput(data.choices[0].message.content);
    }
    if (data.error) {
      return "Error: " + (data.error.message || JSON.stringify(data.error));
    }
    return "Error: Unexpected response format from AI";
  } catch (e) {
    return "Error parsing response: " + e.message;
  }
}
