require("dotenv").config();

const express = require("express");
const cors = require("cors");
const OpenAI = require("openai");

const app = express();

app.use(cors());
app.use(express.json());

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

function extractText(response) {
  if (typeof response.output_text === "string" && response.output_text.trim()) {
    return response.output_text.trim();
  }

  const parts = [];
  for (const item of response.output || []) {
    for (const content of item.content || []) {
      if (content.type === "output_text" && content.text) {
        parts.push(content.text);
      }
    }
  }
  return parts.join("\n").trim();
}

app.get("/", (req, res) => {
  res.json({ ok: true, message: "AI backend is running" });
});

app.post("/analyze-answer", async (req, res) => {
  try {
    const { question, answer, keywords = [] } = req.body;

    if (!question || !answer) {
      return res.status(400).json({
        error: "question and answer are required",
      });
    }

    const response = await openai.responses.create({
      model: "gpt-4o-mini",
      instructions:
        "You are an interview coach. Return only valid JSON. Be practical, helpful, and specific.",
      input: `Analyze this interview answer.

Question: ${question}

Answer: ${answer}

Expected Keywords: ${Array.isArray(keywords) ? keywords.join(", ") : ""}

Return JSON in this exact shape:
{
  "summary": "short overall summary",
  "improvements": ["4 to 6 concrete improvements"],
  "missing_keywords": ["keywords missing from the answer"],
  "suggested_keywords": ["important keywords to add"],
  "better_answer": "a rewritten improved answer"
}`,
      temperature: 0.4,
      max_output_tokens: 900,
    });

    const text = extractText(response);
    const parsed = JSON.parse(text);

    res.json(parsed);
  } catch (error) {
    console.error("analyze-answer error:", error);
    res.status(500).json({
      error: "Failed to analyze answer",
      details: error.message,
    });
  }
});

app.post("/suggest-keywords", async (req, res) => {
  try {
    const { question, type = "General" } = req.body;

    if (!question) {
      return res.status(400).json({
        error: "question is required",
      });
    }

    const response = await openai.responses.create({
      model: "gpt-4o-mini",
      instructions:
        "You suggest interview-related keywords. Return only valid JSON.",
      input: `Suggest keywords for this interview question.

Question: ${question}
Type: ${type}

Return JSON in this exact shape:
{
  "suggested_keywords": ["6 to 10 useful keywords"],
  "reason": "short explanation"
}`,
      temperature: 0.3,
      max_output_tokens: 400,
    });

    const text = extractText(response);
    const parsed = JSON.parse(text);

    res.json(parsed);
  } catch (error) {
    console.error("suggest-keywords error:", error);
    res.status(500).json({
      error: "Failed to suggest keywords",
      details: error.message,
    });
  }
});

const PORT = process.env.PORT || 5000;

app.listen(PORT, "0.0.0.0", () => {
  console.log(`AI backend running on http://0.0.0.0:${PORT}`);
});
