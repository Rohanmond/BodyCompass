# AI Provider Strategy

## MVP Rule

Call both OpenAI and Gemini for:

- meal-photo analysis,
- coach chat.

Then return:

- OpenAI result,
- Gemini result,
- reconciled result.

## Why Both Providers

The user explicitly wants both ChatGPT and Gemini. Dual-provider output also helps with confidence, disagreement, and calorie estimate sanity checks.

## Meal Analysis Prompt Goals

For each meal, providers should estimate:

- calorie range,
- protein/carbs/fat,
- confidence,
- likely hidden calories,
- missing context questions,
- correction recommendation.

Avoid single-number precision unless exact nutrition data exists.

## Coach Chat Prompt Goals

Coach answers should use:

- user profile,
- latest health snapshot,
- recent meals,
- schedule completion,
- goal projection,
- weekly trend when available.

Answers should end with one next best action.

## Safety Rules

The AI should refuse or redirect:

- extreme calorie restriction,
- medical symptoms,
- injury diagnosis,
- eating-disorder reinforcement,
- unsafe supplement/drug advice.

## Configuration

Provider model names must remain backend environment variables:

- `OPENAI_MODEL`
- `GEMINI_MODEL`

Do not hardcode model names in the iOS app.
