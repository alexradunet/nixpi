import { spawn } from 'node:child_process';

export async function promptNixpi(piBin, prompt, options = {}) {
  const timeoutMs = options.timeoutMs ?? 120_000;

  return await new Promise((resolve, reject) => {
    const child = spawn(piBin, ['-p', prompt], {
      env: process.env,
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';
    let finished = false;

    const timeout = setTimeout(() => {
      if (finished) return;
      finished = true;
      child.kill('SIGTERM');
      reject(new Error(`nixpi prompt timed out after ${timeoutMs}ms`));
    }, timeoutMs);

    child.stdout.on('data', (chunk) => {
      stdout += chunk.toString();
    });

    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
    });

    child.once('error', (error) => {
      if (finished) return;
      finished = true;
      clearTimeout(timeout);
      reject(error);
    });

    child.once('close', (code) => {
      if (finished) return;
      finished = true;
      clearTimeout(timeout);

      if (code !== 0) {
        reject(
          new Error(
            `nixpi exited with code ${code}. stderr: ${stderr.trim() || '(empty)'}`
          )
        );
        return;
      }

      resolve(stdout.trim());
    });
  });
}
