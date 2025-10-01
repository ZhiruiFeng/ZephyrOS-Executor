#!/usr/bin/env python3
"""
Mock ZMemory API Server for testing the executor locally.
Run this in one terminal, then run the executor in another.
"""

from flask import Flask, request, jsonify
import time
import uuid
from datetime import datetime

app = Flask(__name__)

# In-memory task storage
tasks = {}
task_queue = []

# Sample tasks for testing
SAMPLE_TASKS = [
    {
        "description": "Write a Python function that calculates the factorial of a number",
        "context": {"language": "python", "difficulty": "easy"}
    },
    {
        "description": "Create a simple REST API endpoint documentation",
        "context": {"format": "markdown"}
    },
    {
        "description": "Explain how async/await works in JavaScript",
        "context": {"audience": "beginners"}
    }
]

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint."""
    return jsonify({"status": "healthy", "timestamp": datetime.utcnow().isoformat()}), 200


@app.route('/tasks/pending', methods=['GET'])
def get_pending_tasks():
    """Get pending tasks for an agent."""
    agent = request.args.get('agent', 'unknown')

    # Get pending tasks
    pending = [task for task in tasks.values() if task['status'] == 'pending']

    # If no pending tasks, create a new sample task occasionally
    if len(pending) == 0 and len(tasks) < 10:
        # Create a new task every other request (simulate real task creation)
        import random
        if random.random() > 0.5:
            sample = random.choice(SAMPLE_TASKS)
            task_id = str(uuid.uuid4())[:8]
            new_task = {
                "id": task_id,
                "description": sample["description"],
                "context": sample["context"],
                "status": "pending",
                "created_at": datetime.utcnow().isoformat(),
                "agent": None
            }
            tasks[task_id] = new_task
            pending.append(new_task)
            print(f"📝 Created new task: {task_id}")

    print(f"📋 Agent '{agent}' requested pending tasks: {len(pending)} found")
    return jsonify({"tasks": pending}), 200


@app.route('/tasks/<task_id>/accept', methods=['POST'])
def accept_task(task_id):
    """Accept a task for execution."""
    data = request.json or {}
    agent = data.get('agent', 'unknown')

    if task_id not in tasks:
        return jsonify({"error": "Task not found"}), 404

    task = tasks[task_id]
    if task['status'] != 'pending':
        return jsonify({"error": "Task not available"}), 400

    task['status'] = 'accepted'
    task['agent'] = agent
    task['accepted_at'] = datetime.utcnow().isoformat()

    print(f"✅ Task {task_id} accepted by agent '{agent}'")
    return jsonify({"success": True, "task": task}), 200


@app.route('/tasks/<task_id>/status', methods=['PATCH'])
def update_task_status(task_id):
    """Update task status."""
    data = request.json or {}
    status = data.get('status')
    progress = data.get('progress')

    if task_id not in tasks:
        return jsonify({"error": "Task not found"}), 404

    task = tasks[task_id]
    if status:
        task['status'] = status
    if progress is not None:
        task['progress'] = progress

    task['updated_at'] = datetime.utcnow().isoformat()

    print(f"🔄 Task {task_id} status updated: {status} ({progress}%)")
    return jsonify({"success": True, "task": task}), 200


@app.route('/tasks/<task_id>/complete', methods=['POST'])
def complete_task(task_id):
    """Mark task as completed."""
    data = request.json or {}
    result = data.get('result', {})

    if task_id not in tasks:
        return jsonify({"error": "Task not found"}), 404

    task = tasks[task_id]
    task['status'] = 'completed'
    task['result'] = result
    task['completed_at'] = datetime.utcnow().isoformat()

    # Print summary
    usage = result.get('usage', {})
    exec_time = result.get('execution_time_seconds', 0)
    print(f"✅ Task {task_id} completed!")
    print(f"   Tokens: {usage.get('total_tokens', 0)}")
    print(f"   Time: {exec_time:.2f}s")
    print(f"   Response preview: {result.get('response', '')[:100]}...")

    return jsonify({"success": True, "task": task}), 200


@app.route('/tasks/<task_id>/fail', methods=['POST'])
def fail_task(task_id):
    """Mark task as failed."""
    data = request.json or {}
    error = data.get('error', 'Unknown error')

    if task_id not in tasks:
        return jsonify({"error": "Task not found"}), 404

    task = tasks[task_id]
    task['status'] = 'failed'
    task['error'] = error
    task['failed_at'] = datetime.utcnow().isoformat()

    print(f"❌ Task {task_id} failed: {error}")
    return jsonify({"success": True, "task": task}), 200


@app.route('/tasks/<task_id>/artifacts', methods=['POST'])
def upload_artifact(task_id):
    """Upload task artifact."""
    data = request.json or {}
    name = data.get('name')
    content = data.get('content')

    if task_id not in tasks:
        return jsonify({"error": "Task not found"}), 404

    task = tasks[task_id]
    if 'artifacts' not in task:
        task['artifacts'] = []

    task['artifacts'].append({
        "name": name,
        "size": len(content),
        "uploaded_at": datetime.utcnow().isoformat()
    })

    print(f"📎 Artifact '{name}' uploaded for task {task_id}")
    return jsonify({"success": True}), 200


@app.route('/tasks', methods=['GET'])
def list_tasks():
    """List all tasks (for debugging)."""
    return jsonify({"tasks": list(tasks.values())}), 200


def main():
    print("""
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║           Mock ZMemory API Server                 ║
║              (for testing)                        ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝

Starting server on http://localhost:5000

Endpoints:
  GET  /health                     - Health check
  GET  /tasks/pending              - Get pending tasks
  POST /tasks/<id>/accept          - Accept a task
  PATCH /tasks/<id>/status         - Update task status
  POST /tasks/<id>/complete        - Complete a task
  POST /tasks/<id>/fail            - Fail a task
  POST /tasks/<id>/artifacts       - Upload artifact
  GET  /tasks                      - List all tasks

Configure your .env file:
  ZMEMORY_API_URL=http://localhost:5000

Press Ctrl+C to stop
""")

    app.run(host='0.0.0.0', port=5000, debug=False)


if __name__ == '__main__':
    main()
