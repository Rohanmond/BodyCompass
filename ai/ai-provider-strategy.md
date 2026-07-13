# AI Provider Strategy

## MVP Rule

Call both OpenAI and Gemini for:

- meal-photo analysis,
- coach chat.
- weekly progress-photo analysis.

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

When Coach suggests a routine change, it must return a structured proposal rather than mutate the routine. The proposal must include the exact days/exercises changed, sets and rep ranges, rationale, expected recovery impact, and any missing information. It remains pending until the user confirms or edits it.

Training prescriptions should consider experience, equipment, limitations, recent set performance, target effort, sleep, soreness, adherence, and swimming load. Prefer rep ranges, RIR/RPE, rest periods, and explicit progression rules over fixed-load guesses.

## Progress Photo Prompt Goals

For each standardized weekly check-in, providers should return:

- a broad body-fat percentage range,
- confidence and image-quality limitations,
- visible change compared with prior comparable photos,
- areas where no reliable conclusion can be made,
- suggestions grounded in weight, adherence, activity, and sleep trends,
- one next-week action.

Providers must not identify the person, judge attractiveness, infer unrelated sensitive traits, diagnose conditions, or present the estimate as a clinical measurement.

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
