import cron from 'node-cron';
import { exec } from 'child_process';

// Read PYTHON_CMD from environment (supports venv path on Pi)
const pythonCmd = process.env.PYTHON_CMD || 'python3';
const schedule = process.env.REPORT_CRON || '*/5 * * * *';

console.log(`Report scheduler started. PYTHON_CMD=${pythonCmd}, schedule="${schedule}"`);

cron.schedule(schedule, () => {
    console.log('Running Python report script...');
    exec(`${pythonCmd} request_reports.py`, (error, stdout, stderr) => {
        if (error) {
            console.error(`Error executing script: ${error.message}`);
            return;
        }

        if (stderr) {
            console.error(`stderr: ${stderr}`);
            return;
        }

        console.log(`stdout: ${stdout}`);
    });
});
