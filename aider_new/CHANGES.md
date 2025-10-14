# Changes to Fix Premature Aider Exit

## Problem
Aider-genius was exiting prematurely with "Task input cancelled by user" when running in the interactive Terminal workflow. This was caused by `EOFError` being caught and treated as user cancellation.

## Root Cause
When `input()` is called in certain conditions (redirected stdin, after receiving piped input, etc.), it raises `EOFError`. The original code caught both `KeyboardInterrupt` and `EOFError` together and treated them both as cancellation.

## Solution
Modified the exception handling in both locations where user input is requested:

### Files Modified
1. `/benchmarks/aider-genius/aider/genius.jac`
2. `/Agentic-AI/aider-genius/aider/genius.jac`

### Changes Made

#### 1. Input Collection Function (around line 700)
**Before:**
```jac
} except (KeyboardInterrupt, EOFError) {
    coder.io.tool_output("\nExiting Genius Agent...");
    return ("", False);
}
```

**After:**
```jac
} except KeyboardInterrupt {
    # Only treat Ctrl+C as explicit cancellation
    coder.io.tool_output("\nOperation cancelled by user (Ctrl+C).");
    return ("", False);
} except Exception as e {
    # Don't treat EOF or other errors as cancellation
    # Log the error and return empty to retry
    coder.io.tool_output(f"Input error: {str(e)} - continuing...");
    return ("empty", True);
}
```

#### 2. Planning Phase Input Loop (around line 842)
**Before:**
```jac
} else {
    self.coder.io.tool_output("No task provided. Cannot proceed without a specific task.");
    here.status = "failed";
    here.error = "No task provided";
    return;
}
} except (KeyboardInterrupt, EOFError) {
    self.coder.io.tool_output("\nTask input cancelled by user.");
    here.status = "failed";
    return;
} except Exception as e {
    self.coder.io.tool_output(f"Error getting user input: {str(e)}");
    here.status = "failed";
    return;
}
```

**After:**
```jac
} else {
    self.coder.io.tool_output("No task provided. Please enter a task description.");
    continue;  # Ask for input again instead of failing
}
} except KeyboardInterrupt {
    # Only treat Ctrl+C as explicit cancellation, not EOF
    self.coder.io.tool_output("\nOperation cancelled by user (Ctrl+C).");
    here.status = "cancelled";
    return;
} except Exception as e {
    # Log error but continue trying to get input
    self.coder.io.tool_output(f"Error getting user input: {str(e)}");
    import time;
    time.sleep(0.1);  # Brief pause before retrying
    continue;  # Try again instead of failing
}
```

### Additional Changes
- Added explicit handling for `/exit` and `/quit` commands
- Changed empty input handling to continue asking for input instead of failing
- Added brief sleep before retrying after input errors to prevent tight loops

## Exit Conditions
After these changes, aider will only exit when:
1. User explicitly types `/exit` or `/quit`
2. User presses Ctrl+C (KeyboardInterrupt)
3. Terminal window is closed (process termination)
4. Aider completes its task successfully

## Testing
Test the changes by running:
```bash
cd /Users/jayanaka-98/Repos/PromptCompEval/aider_new
make run_one INSTANCE_ID=astropy__astropy-6938
```

The Terminal window should:
1. Open with aider running
2. Show the `>` prompt after initialization
3. Receive the task via `pty_run.py`
4. Process the task without premature exit
5. Stay open until you close the Terminal window
