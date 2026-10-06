# Benchmark Apps (Memory Retrieval, Task Manager, Content Creator)

Evaluation datasets, runners, and raw outputs for three of the five benchmark
applications in the SemText paper (Table 1).

`memory_retrieval/test_data/` comes from this repo's `friendzone` branch
(`99c29e1`), copied unchanged.

The Task Manager and Content Creator folders were copied from an
uncommitted/gitignored working tree of
[jaseci-labs/Agentic-AI](https://github.com/jaseci-labs/Agentic-AI) (local clone
at commit `6b450ac`) so they are version-controlled. Folder contents are
byte-identical to the originals; only the folder names were changed to match
the paper's variants.

| Folder | Paper variant | Original path in Agentic-AI | Model currently set |
|---|---|---|---|
| `task_manager/pe_langgraph/` | PE | `task_manager/langgraph/` | gpt-4o (`python/app.py`) |
| `task_manager/mtp/` | MTP | `task_manager/byllm/BE/v3_nosem/` | ollama/gemma3:27b |
| `task_manager/mtp_sem/` | MTP + SemTexts | `task_manager/byllm/BE/v2/` | ollama/gemma3:27b |
| `content_creator/mtp/` | MTP | `content_creator/byLLM/approach_without_sem/` | gpt-4o |
| `content_creator/mtp_sem/` | MTP + SemTexts | `content_creator/byLLM/approach_2/` | ollama/gemma3:27b |

## Datasets

- **Memory Retrieval:** `memory_retrieval/test_data/user_NNN.json` covers 20 users
  (the paper uses 60). Each file has 10 `memories` (`memory_id`, `summary`, `when`,
  `who`, `where`, `what`) and 5 `qa_pairs` (`qid`, `question`, `answer_gold`,
  `evidence` = gold memory IDs), giving 100 queries in total. **Known issue:**
  `user_004.json` is an exact duplicate of `user_005.json` (both have
  `user_id: user_005`), so there are 19 unique users and 95 unique queries.
- **Task Manager:** `generalized_synthetic_agent_data.json` with 220 queries
  (100 `task_handling`, 20 `task_summaries`, 100 `email_handling`). The same file
  is in each variant folder because the runners load it from the working directory.
- **Content Creator:** `InstructEvalImpact.json` with 200 InstructEval prompts
  across 4 categories (fields: `Category`, `Definition`, `Prompt`).

## Raw outputs included

- `task_manager/*/taskman_<timestamp>.jsonl`: one record per query
  (`type`, `utterance`, `response`). Complete 220-query runs exist for
  `pe_langgraph` (`taskman_20251105_092226`) and `mtp` (`taskman_20251102_074248`).
  The largest `mtp_sem` run (`taskman_20251105_094355`) covers 118/220 queries and has no email queries.
- `content_creator/mtp_sem/gemma_out/`: 136 per-prompt output files from the Gemma run.

## Not here yet

- Memory Retrieval: the other 40 users / 200 queries, the runner, and the F1 scorer
- PE implementation of Content Creator
- LLM-as-a-judge scoring scripts for Task Manager and Content Creator
- Docstring variants (RQ4) and Content Creator ablation variants (RQ3)

## Running

Set `SENDER_EMAIL`, `SENDER_PASSWORD` and `SENDER_NAME` (see `task_manager/.env.example`)
for the email agent, plus `OPENAI_API_KEY` for gpt-4o. Runners read the dataset and
write outputs relative to the current directory, so run them from the folder that
holds the dataset:

```bash
cd task_manager/mtp_sem && jac run main.jac       # likewise for the other MTP folders
cd task_manager/pe_langgraph/python && python app.py
```
