# ZephyrOS Executor Implementation Plan

## 📋 Overview

This document outlines the complete implementation plan for the Agent Workspace system, including database schema, backend API (ZMemory), and Swift executor client.

---

## 🗄️ Phase 1: Database Schema (✅ COMPLETED)

### Location
- **File**: `/Users/zhiruifeng/Workspace/dev/ZephyrOS/supabase/executor_schema.sql`
- **Status**: Schema created and documented

### Tables Created
1. `executor_devices` - Device registration
2. `executor_agent_workspaces` - Workspace tracking
3. `executor_workspace_tasks` - Task assignments
4. `executor_workspace_events` - Audit log
5. `executor_workspace_artifacts` - File tracking
6. `executor_workspace_metrics` - Performance monitoring

### Next Steps
```bash
# Apply schema to Supabase
cd /Users/zhiruifeng/Workspace/dev/ZephyrOS
supabase db push

# Or manually via Supabase Dashboard SQL Editor
# Copy contents of supabase/executor_schema.sql
```

---

## 🔧 Phase 2: ZMemory Backend API

### Location
- **Base Path**: `/Users/zhiruifeng/Workspace/dev/ZephyrOS/apps/zmemory`
- **Architecture**: Follow `DEVELOPMENT_GUIDELINES.md`

### 2.1 Create Validation Schemas

**File**: `lib/validation/executor-schemas.ts`

```typescript
import { z } from 'zod';

// =====================================================
// EXECUTOR DEVICES SCHEMAS
// =====================================================

export const ExecutorDeviceCreateSchema = z.object({
  device_name: z.string().min(1).max(100),
  device_id: z.string().uuid(),
  platform: z.enum(['macos', 'linux', 'windows']),
  os_version: z.string().optional(),
  executor_version: z.string().optional(),
  root_workspace_path: z.string().min(1),
  max_concurrent_workspaces: z.number().int().min(1).max(10).default(3),
  max_disk_usage_gb: z.number().int().min(1).max(500).default(50),
  default_shell: z.string().default('/bin/zsh'),
  default_timeout_minutes: z.number().int().min(1).max(300).default(30),
  allowed_commands: z.array(z.string()).optional(),
  environment_vars: z.record(z.string()).optional(),
  system_prompt: z.string().optional(),
  claude_code_path: z.string().optional(),
  features: z.array(z.string()).optional(),
  notes: z.string().optional(),
  tags: z.array(z.string()).optional()
});

export const ExecutorDeviceUpdateSchema = ExecutorDeviceCreateSchema.partial();

export const ExecutorDeviceQuerySchema = z.object({
  status: z.enum(['active', 'inactive', 'maintenance', 'disabled']).optional(),
  is_online: z.boolean().optional(),
  platform: z.enum(['macos', 'linux', 'windows']).optional()
});

// =====================================================
// EXECUTOR WORKSPACES SCHEMAS
// =====================================================

export const ExecutorWorkspaceCreateSchema = z.object({
  executor_device_id: z.string().uuid(),
  agent_id: z.string().uuid(),
  workspace_path: z.string().min(1),
  relative_path: z.string().min(1),
  metadata_path: z.string().optional(),
  repo_url: z.string().url().optional(),
  repo_branch: z.string().default('main'),
  project_type: z.enum(['swift', 'python', 'nodejs', 'go', 'rust', 'generic']).optional(),
  project_name: z.string().optional(),
  allowed_commands: z.array(z.string()).optional(),
  environment_vars: z.record(z.string()).optional(),
  system_prompt: z.string().optional(),
  execution_timeout_minutes: z.number().int().min(1).max(300).default(30),
  enable_network: z.boolean().default(true),
  enable_git: z.boolean().default(true),
  max_disk_usage_mb: z.number().int().min(100).max(50000).default(5000)
});

export const ExecutorWorkspaceUpdateSchema = z.object({
  status: z.enum([
    'creating', 'initializing', 'cloning', 'ready', 'assigned',
    'running', 'paused', 'completed', 'failed', 'archived', 'cleanup'
  ]).optional(),
  progress_percentage: z.number().int().min(0).max(100).optional(),
  current_phase: z.string().optional(),
  current_step: z.string().optional(),
  disk_usage_bytes: z.number().int().min(0).optional(),
  file_count: z.number().int().min(0).optional()
});

export const ExecutorWorkspaceQuerySchema = z.object({
  executor_device_id: z.string().uuid().optional(),
  agent_id: z.string().uuid().optional(),
  status: z.enum([
    'creating', 'initializing', 'cloning', 'ready', 'assigned',
    'running', 'paused', 'completed', 'failed', 'archived', 'cleanup'
  ]).optional(),
  limit: z.number().int().min(1).max(100).default(50),
  offset: z.number().int().min(0).default(0)
});

// =====================================================
// EXECUTOR WORKSPACE TASKS SCHEMAS
// =====================================================

export const ExecutorWorkspaceTaskCreateSchema = z.object({
  workspace_id: z.string().uuid(),
  ai_task_id: z.string().uuid(),
  prompt_file_path: z.string().optional(),
  output_file_path: z.string().optional(),
  estimated_cost_usd: z.number().optional(),
  max_retries: z.number().int().min(0).max(10).default(3)
});

export const ExecutorWorkspaceTaskUpdateSchema = z.object({
  status: z.enum([
    'assigned', 'queued', 'starting', 'running', 'paused',
    'completed', 'failed', 'timeout', 'cancelled'
  ]).optional(),
  result_file_path: z.string().optional(),
  exit_code: z.number().int().optional(),
  output_summary: z.string().optional(),
  error_message: z.string().optional(),
  execution_duration_seconds: z.number().int().optional(),
  cpu_time_seconds: z.number().int().optional(),
  memory_peak_mb: z.number().int().optional(),
  actual_cost_usd: z.number().optional()
});

// =====================================================
// EXECUTOR WORKSPACE EVENTS SCHEMAS
// =====================================================

export const ExecutorWorkspaceEventCreateSchema = z.object({
  workspace_id: z.string().uuid(),
  workspace_task_id: z.string().uuid().optional(),
  executor_device_id: z.string().uuid(),
  event_type: z.string().min(1),
  event_category: z.enum(['lifecycle', 'task', 'error', 'resource', 'system']).default('info'),
  message: z.string().min(1),
  details: z.record(z.any()).optional(),
  level: z.enum(['debug', 'info', 'warning', 'error', 'critical']).default('info'),
  source: z.string().optional()
});

// =====================================================
// EXECUTOR WORKSPACE ARTIFACTS SCHEMAS
// =====================================================

export const ExecutorWorkspaceArtifactCreateSchema = z.object({
  workspace_id: z.string().uuid(),
  workspace_task_id: z.string().uuid().optional(),
  file_path: z.string().min(1),
  file_name: z.string().min(1),
  file_extension: z.string().optional(),
  artifact_type: z.enum([
    'source_code', 'config', 'documentation', 'test', 'build_output',
    'log', 'result', 'prompt', 'screenshot', 'data', 'other'
  ]),
  file_size_bytes: z.number().int().min(0).optional(),
  mime_type: z.string().optional(),
  checksum: z.string().optional(),
  storage_type: z.enum(['reference', 'inline', 'external']).default('reference'),
  content: z.string().optional(),
  content_preview: z.string().optional(),
  external_url: z.string().url().optional(),
  language: z.string().optional(),
  line_count: z.number().int().optional(),
  description: z.string().optional(),
  tags: z.array(z.string()).optional(),
  is_output: z.boolean().default(false),
  is_modified: z.boolean().default(false)
});

// =====================================================
// EXECUTOR WORKSPACE METRICS SCHEMAS
// =====================================================

export const ExecutorWorkspaceMetricCreateSchema = z.object({
  workspace_id: z.string().uuid(),
  workspace_task_id: z.string().uuid().optional(),
  executor_device_id: z.string().uuid(),
  cpu_usage_percent: z.number().min(0).max(100).optional(),
  memory_usage_mb: z.number().int().min(0).optional(),
  disk_usage_mb: z.number().int().min(0).optional(),
  disk_read_mb: z.number().int().min(0).optional(),
  disk_write_mb: z.number().int().min(0).optional(),
  network_in_mb: z.number().int().min(0).optional(),
  network_out_mb: z.number().int().min(0).optional(),
  process_count: z.number().int().min(0).optional(),
  thread_count: z.number().int().min(0).optional(),
  open_files_count: z.number().int().min(0).optional(),
  command_execution_count: z.number().int().min(0).optional(),
  command_success_count: z.number().int().min(0).optional(),
  command_failure_count: z.number().int().min(0).optional(),
  avg_command_duration_ms: z.number().int().min(0).optional(),
  cumulative_cost_usd: z.number().min(0).optional(),
  metric_type: z.enum(['snapshot', 'aggregated', 'peak', 'average']).default('snapshot'),
  aggregation_period_minutes: z.number().int().optional()
});

// Export all schemas
export const ExecutorSchemas = {
  Device: {
    Create: ExecutorDeviceCreateSchema,
    Update: ExecutorDeviceUpdateSchema,
    Query: ExecutorDeviceQuerySchema
  },
  Workspace: {
    Create: ExecutorWorkspaceCreateSchema,
    Update: ExecutorWorkspaceUpdateSchema,
    Query: ExecutorWorkspaceQuerySchema
  },
  WorkspaceTask: {
    Create: ExecutorWorkspaceTaskCreateSchema,
    Update: ExecutorWorkspaceTaskUpdateSchema
  },
  Event: {
    Create: ExecutorWorkspaceEventCreateSchema
  },
  Artifact: {
    Create: ExecutorWorkspaceArtifactCreateSchema
  },
  Metric: {
    Create: ExecutorWorkspaceMetricCreateSchema
  }
};
```

### 2.2 Create Repository Layer

**File**: `lib/database/repositories/executor-repository.ts`

```typescript
import { SupabaseClient } from '@supabase/supabase-js';
import { BaseRepository } from './base-repository';

export class ExecutorDeviceRepository extends BaseRepository {
  constructor(supabase: SupabaseClient, userId: string) {
    super(supabase, userId);
  }

  async createDevice(data: any) {
    return this.supabase
      .from('executor_devices')
      .insert({ ...data, user_id: this.userId })
      .select()
      .single();
  }

  async getDevice(deviceId: string) {
    return this.supabase
      .from('executor_devices')
      .select('*')
      .eq('id', deviceId)
      .eq('user_id', this.userId)
      .single();
  }

  async listDevices(filters?: any) {
    let query = this.supabase
      .from('executor_devices')
      .select('*')
      .eq('user_id', this.userId);

    if (filters?.status) {
      query = query.eq('status', filters.status);
    }
    if (filters?.is_online !== undefined) {
      query = query.eq('is_online', filters.is_online);
    }
    if (filters?.platform) {
      query = query.eq('platform', filters.platform);
    }

    return query.order('created_at', { ascending: false });
  }

  async updateDevice(deviceId: string, data: any) {
    return this.supabase
      .from('executor_devices')
      .update(data)
      .eq('id', deviceId)
      .eq('user_id', this.userId)
      .select()
      .single();
  }

  async updateDeviceHeartbeat(deviceId: string) {
    return this.supabase.rpc('update_executor_device_heartbeat', {
      device_uuid: deviceId
    });
  }

  async deleteDevice(deviceId: string) {
    return this.supabase
      .from('executor_devices')
      .delete()
      .eq('id', deviceId)
      .eq('user_id', this.userId);
  }
}

export class ExecutorWorkspaceRepository extends BaseRepository {
  constructor(supabase: SupabaseClient, userId: string) {
    super(supabase, userId);
  }

  async createWorkspace(data: any) {
    return this.supabase
      .from('executor_agent_workspaces')
      .insert({ ...data, user_id: this.userId })
      .select()
      .single();
  }

  async getWorkspace(workspaceId: string) {
    return this.supabase
      .from('executor_agent_workspaces')
      .select(`
        *,
        executor_device:executor_devices(*),
        agent:ai_agents(*),
        tasks:executor_workspace_tasks(*)
      `)
      .eq('id', workspaceId)
      .eq('user_id', this.userId)
      .single();
  }

  async listWorkspaces(filters?: any) {
    let query = this.supabase
      .from('executor_agent_workspaces')
      .select(`
        *,
        executor_device:executor_devices(device_name, platform, is_online),
        agent:ai_agents(name),
        tasks:executor_workspace_tasks(ai_task_id, status)
      `)
      .eq('user_id', this.userId);

    if (filters?.executor_device_id) {
      query = query.eq('executor_device_id', filters.executor_device_id);
    }
    if (filters?.agent_id) {
      query = query.eq('agent_id', filters.agent_id);
    }
    if (filters?.status) {
      query = query.eq('status', filters.status);
    }

    query = query.order('created_at', { ascending: false });

    if (filters?.limit) {
      query = query.limit(filters.limit);
    }
    if (filters?.offset) {
      query = query.range(filters.offset, filters.offset + (filters.limit || 50) - 1);
    }

    return query;
  }

  async updateWorkspace(workspaceId: string, data: any) {
    return this.supabase
      .from('executor_agent_workspaces')
      .update(data)
      .eq('id', workspaceId)
      .eq('user_id', this.userId)
      .select()
      .single();
  }

  async deleteWorkspace(workspaceId: string) {
    return this.supabase
      .from('executor_agent_workspaces')
      .delete()
      .eq('id', workspaceId)
      .eq('user_id', this.userId);
  }
}

export class ExecutorWorkspaceTaskRepository extends BaseRepository {
  // Similar pattern for workspace tasks
  async createWorkspaceTask(data: any) { /* ... */ }
  async getWorkspaceTask(taskId: string) { /* ... */ }
  async updateWorkspaceTask(taskId: string, data: any) { /* ... */ }
  async listWorkspaceTasks(workspaceId: string) { /* ... */ }
}

export class ExecutorEventRepository extends BaseRepository {
  async createEvent(data: any) {
    return this.supabase
      .from('executor_workspace_events')
      .insert({ ...data, user_id: this.userId })
      .select()
      .single();
  }

  async listEvents(workspaceId: string, filters?: any) {
    let query = this.supabase
      .from('executor_workspace_events')
      .select('*')
      .eq('workspace_id', workspaceId)
      .eq('user_id', this.userId);

    if (filters?.level) {
      query = query.eq('level', filters.level);
    }
    if (filters?.event_category) {
      query = query.eq('event_category', filters.event_category);
    }

    return query.order('created_at', { ascending: false }).limit(filters?.limit || 100);
  }
}

export class ExecutorArtifactRepository extends BaseRepository {
  async createArtifact(data: any) { /* ... */ }
  async getArtifact(artifactId: string) { /* ... */ }
  async listArtifacts(workspaceId: string, filters?: any) { /* ... */ }
}

export class ExecutorMetricRepository extends BaseRepository {
  async createMetric(data: any) { /* ... */ }
  async listMetrics(workspaceId: string, filters?: any) { /* ... */ }
  async getResourceSummary(workspaceId: string) {
    return this.supabase.rpc('get_workspace_resource_summary', {
      workspace_uuid: workspaceId
    });
  }
}
```

### 2.3 Create Service Layer

**File**: `lib/services/executor-service.ts`

```typescript
import { BaseService } from './base-service';
import type { ServiceResult } from './types';
import {
  ExecutorDeviceRepository,
  ExecutorWorkspaceRepository,
  ExecutorWorkspaceTaskRepository,
  ExecutorEventRepository,
  ExecutorArtifactRepository,
  ExecutorMetricRepository
} from '@/database/repositories/executor-repository';

export class ExecutorService extends BaseService {
  private deviceRepo: ExecutorDeviceRepository;
  private workspaceRepo: ExecutorWorkspaceRepository;
  private taskRepo: ExecutorWorkspaceTaskRepository;
  private eventRepo: ExecutorEventRepository;
  private artifactRepo: ExecutorArtifactRepository;
  private metricRepo: ExecutorMetricRepository;

  constructor(config: { userId: string }) {
    super(config);
    const supabase = this.getSupabaseClient();

    this.deviceRepo = new ExecutorDeviceRepository(supabase, config.userId);
    this.workspaceRepo = new ExecutorWorkspaceRepository(supabase, config.userId);
    this.taskRepo = new ExecutorWorkspaceTaskRepository(supabase, config.userId);
    this.eventRepo = new ExecutorEventRepository(supabase, config.userId);
    this.artifactRepo = new ExecutorArtifactRepository(supabase, config.userId);
    this.metricRepo = new ExecutorMetricRepository(supabase, config.userId);
  }

  // Device Management
  async registerDevice(data: any): Promise<ServiceResult<any>> {
    try {
      const result = await this.deviceRepo.createDevice(data);
      if (result.error) throw result.error;
      return { data: result.data, error: null };
    } catch (error) {
      return this.handleError(error);
    }
  }

  async sendDeviceHeartbeat(deviceId: string): Promise<ServiceResult<void>> {
    try {
      const result = await this.deviceRepo.updateDeviceHeartbeat(deviceId);
      if (result.error) throw result.error;
      return { data: undefined, error: null };
    } catch (error) {
      return this.handleError(error);
    }
  }

  // Workspace Management
  async createWorkspace(data: any): Promise<ServiceResult<any>> {
    try {
      const result = await this.workspaceRepo.createWorkspace(data);
      if (result.error) throw result.error;

      // Log event
      await this.logEvent({
        workspace_id: result.data.id,
        executor_device_id: data.executor_device_id,
        event_type: 'workspace_created',
        event_category: 'lifecycle',
        message: `Workspace created at ${data.workspace_path}`,
        level: 'info',
        source: 'ExecutorService'
      });

      return { data: result.data, error: null };
    } catch (error) {
      return this.handleError(error);
    }
  }

  async updateWorkspaceStatus(
    workspaceId: string,
    status: string,
    progress?: number
  ): Promise<ServiceResult<any>> {
    try {
      const updateData: any = { status };
      if (progress !== undefined) {
        updateData.progress_percentage = progress;
      }

      const result = await this.workspaceRepo.updateWorkspace(workspaceId, updateData);
      if (result.error) throw result.error;

      // Log event
      await this.logEvent({
        workspace_id: workspaceId,
        executor_device_id: result.data.executor_device_id,
        event_type: 'status_changed',
        event_category: 'lifecycle',
        message: `Workspace status changed to ${status}`,
        details: { status, progress },
        level: 'info',
        source: 'ExecutorService'
      });

      return { data: result.data, error: null };
    } catch (error) {
      return this.handleError(error);
    }
  }

  // Task Management
  async assignTask(workspaceId: string, aiTaskId: string, config: any): Promise<ServiceResult<any>> {
    try {
      const result = await this.taskRepo.createWorkspaceTask({
        workspace_id: workspaceId,
        ai_task_id: aiTaskId,
        ...config
      });
      if (result.error) throw result.error;

      // Update workspace status
      await this.updateWorkspaceStatus(workspaceId, 'assigned');

      // Log event
      await this.logEvent({
        workspace_id: workspaceId,
        workspace_task_id: result.data.id,
        executor_device_id: result.data.executor_device_id,
        event_type: 'task_assigned',
        event_category: 'task',
        message: `AI Task ${aiTaskId} assigned to workspace`,
        level: 'info',
        source: 'ExecutorService'
      });

      return { data: result.data, error: null };
    } catch (error) {
      return this.handleError(error);
    }
  }

  // Event Logging
  async logEvent(eventData: any): Promise<ServiceResult<void>> {
    try {
      const result = await this.eventRepo.createEvent(eventData);
      if (result.error) throw result.error;
      return { data: undefined, error: null };
    } catch (error) {
      return this.handleError(error);
    }
  }

  // Artifact Management
  async uploadArtifact(artifactData: any): Promise<ServiceResult<any>> {
    try {
      const result = await this.artifactRepo.createArtifact(artifactData);
      if (result.error) throw result.error;
      return { data: result.data, error: null };
    } catch (error) {
      return this.handleError(error);
    }
  }

  // Metrics
  async recordMetrics(metricData: any): Promise<ServiceResult<void>> {
    try {
      const result = await this.metricRepo.createMetric(metricData);
      if (result.error) throw result.error;
      return { data: undefined, error: null };
    } catch (error) {
      return this.handleError(error);
    }
  }
}

// Factory function
export function createExecutorService(config: { userId: string }) {
  return new ExecutorService(config);
}
```

### 2.4 Create API Routes

**Directory Structure**:
```
app/api/
├── executor/
│   ├── devices/
│   │   ├── route.ts              # GET (list), POST (register)
│   │   └── [id]/
│   │       ├── route.ts          # GET, PUT, DELETE
│   │       └── heartbeat/
│   │           └── route.ts      # POST
│   ├── workspaces/
│   │   ├── route.ts              # GET (list), POST (create)
│   │   └── [id]/
│   │       ├── route.ts          # GET, PUT, DELETE
│   │       ├── tasks/
│   │       │   └── route.ts      # GET (list), POST (assign)
│   │       ├── events/
│   │       │   └── route.ts      # GET (list), POST (log)
│   │       ├── artifacts/
│   │       │   └── route.ts      # GET (list), POST (upload)
│   │       └── metrics/
│   │           └── route.ts      # GET (list), POST (record)
│   └── tasks/
│       └── [id]/
│           └── route.ts          # GET, PUT (update status)
```

**Example Route**: `app/api/executor/devices/route.ts`

```typescript
import { NextResponse } from 'next/server';
import { withStandardMiddleware, type EnhancedRequest } from '@/middleware';
import { createExecutorService } from '@/services';
import { ExecutorSchemas } from '@/validation/executor-schemas';

async function handleGetDevices(request: EnhancedRequest): Promise<NextResponse> {
  const query = request.validatedQuery;
  const userId = request.userId!;

  const executorService = createExecutorService({ userId });
  const result = await executorService.listDevices(query);

  if (result.error) throw result.error;

  return NextResponse.json({
    devices: result.data || []
  });
}

async function handleRegisterDevice(request: EnhancedRequest): Promise<NextResponse> {
  const deviceData = request.validatedBody;
  const userId = request.userId!;

  const executorService = createExecutorService({ userId });
  const result = await executorService.registerDevice(deviceData);

  if (result.error) throw result.error;

  return NextResponse.json({
    device: result.data
  }, { status: 201 });
}

export const GET = withStandardMiddleware(handleGetDevices, {
  validation: { querySchema: ExecutorSchemas.Device.Query },
  rateLimit: { windowMs: 15 * 60 * 1000, maxRequests: 300 }
});

export const POST = withStandardMiddleware(handleRegisterDevice, {
  validation: { bodySchema: ExecutorSchemas.Device.Create },
  rateLimit: { windowMs: 15 * 60 * 1000, maxRequests: 50 }
});
```

---

## 📱 Phase 3: Swift Executor Client

### Location
- **Base Path**: `/Users/zhiruifeng/Workspace/dev/ZephyrOS-Executor/ZephyrOS Executor/ZephyrOS Executor`

### 3.1 Create Models

**File**: `Models/ExecutorModels.swift`

```swift
import Foundation

// MARK: - Executor Device

struct ExecutorDevice: Codable, Identifiable {
    let id: String
    let userId: String
    var deviceName: String
    let deviceId: String
    let platform: String
    var osVersion: String?
    var executorVersion: String?
    var rootWorkspacePath: String
    var maxConcurrentWorkspaces: Int
    var maxDiskUsageGb: Int
    var defaultShell: String
    var defaultTimeoutMinutes: Int
    var allowedCommands: [String]?
    var environmentVars: [String: String]?
    var systemPrompt: String?
    var claudeCodePath: String?
    var features: [String]?
    var status: DeviceStatus
    var isOnline: Bool
    var lastHeartbeatAt: Date?
    var currentWorkspacesCount: Int
    var currentDiskUsageGb: Double
    var notes: String?
    var tags: [String]?
    let createdAt: Date
    var updatedAt: Date
    var lastOnlineAt: Date?

    enum DeviceStatus: String, Codable {
        case active, inactive, maintenance, disabled
    }

    enum CodingKeys: String, CodingKey {
        case id, platform, status, notes, tags
        case userId = "user_id"
        case deviceName = "device_name"
        case deviceId = "device_id"
        case osVersion = "os_version"
        case executorVersion = "executor_version"
        case rootWorkspacePath = "root_workspace_path"
        case maxConcurrentWorkspaces = "max_concurrent_workspaces"
        case maxDiskUsageGb = "max_disk_usage_gb"
        case defaultShell = "default_shell"
        case defaultTimeoutMinutes = "default_timeout_minutes"
        case allowedCommands = "allowed_commands"
        case environmentVars = "environment_vars"
        case systemPrompt = "system_prompt"
        case claudeCodePath = "claude_code_path"
        case features
        case isOnline = "is_online"
        case lastHeartbeatAt = "last_heartbeat_at"
        case currentWorkspacesCount = "current_workspaces_count"
        case currentDiskUsageGb = "current_disk_usage_gb"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastOnlineAt = "last_online_at"
    }
}

// MARK: - Executor Workspace

struct ExecutorWorkspace: Codable, Identifiable {
    let id: String
    let executorDeviceId: String
    let agentId: String
    let userId: String
    var workspacePath: String
    var relativePath: String
    var metadataPath: String?
    var repoUrl: String?
    var repoBranch: String
    var projectType: String?
    var projectName: String?
    var allowedCommands: [String]?
    var environmentVars: [String: String]?
    var systemPrompt: String?
    var executionTimeoutMinutes: Int
    var enableNetwork: Bool
    var enableGit: Bool
    var maxDiskUsageMb: Int
    var status: WorkspaceStatus
    var progressPercentage: Int
    var currentPhase: String?
    var currentStep: String?
    var lastHeartbeatAt: Date?
    var diskUsageBytes: Int64
    var fileCount: Int
    let createdAt: Date
    var initializedAt: Date?
    var readyAt: Date?
    var archivedAt: Date?
    var updatedAt: Date

    enum WorkspaceStatus: String, Codable {
        case creating, initializing, cloning, ready, assigned
        case running, paused, completed, failed, archived, cleanup
    }

    enum CodingKeys: String, CodingKey {
        case id, status
        case executorDeviceId = "executor_device_id"
        case agentId = "agent_id"
        case userId = "user_id"
        case workspacePath = "workspace_path"
        case relativePath = "relative_path"
        case metadataPath = "metadata_path"
        case repoUrl = "repo_url"
        case repoBranch = "repo_branch"
        case projectType = "project_type"
        case projectName = "project_name"
        case allowedCommands = "allowed_commands"
        case environmentVars = "environment_vars"
        case systemPrompt = "system_prompt"
        case executionTimeoutMinutes = "execution_timeout_minutes"
        case enableNetwork = "enable_network"
        case enableGit = "enable_git"
        case maxDiskUsageMb = "max_disk_usage_mb"
        case progressPercentage = "progress_percentage"
        case currentPhase = "current_phase"
        case currentStep = "current_step"
        case lastHeartbeatAt = "last_heartbeat_at"
        case diskUsageBytes = "disk_usage_bytes"
        case fileCount = "file_count"
        case createdAt = "created_at"
        case initializedAt = "initialized_at"
        case readyAt = "ready_at"
        case archivedAt = "archived_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Additional models for WorkspaceTask, Event, Artifact, Metric...
```

### 3.2 Extend ZMemoryClient

**File**: `Services/ZMemoryClient+Executor.swift`

```swift
extension ZMemoryClient {
    // Device Management
    func registerDevice(_ device: ExecutorDevice) async throws -> ExecutorDevice
    func getDevice(id: String) async throws -> ExecutorDevice
    func listDevices() async throws -> [ExecutorDevice]
    func updateDevice(id: String, updates: [String: Any]) async throws -> ExecutorDevice
    func sendDeviceHeartbeat(id: String) async throws

    // Workspace Management
    func createWorkspace(_ workspace: ExecutorWorkspace) async throws -> ExecutorWorkspace
    func getWorkspace(id: String) async throws -> ExecutorWorkspace
    func listWorkspaces(filters: [String: Any]?) async throws -> [ExecutorWorkspace]
    func updateWorkspace(id: String, updates: [String: Any]) async throws -> ExecutorWorkspace

    // Task Assignment
    func assignTaskToWorkspace(workspaceId: String, taskId: String, config: [String: Any]) async throws

    // Event Logging
    func logWorkspaceEvent(workspaceId: String, event: WorkspaceEvent) async throws

    // Artifacts
    func uploadArtifact(workspaceId: String, artifact: WorkspaceArtifact) async throws

    // Metrics
    func recordMetrics(workspaceId: String, metrics: WorkspaceMetrics) async throws
}
```

### 3.3 Create WorkspaceManager

**File**: `Services/WorkspaceManager.swift`

```swift
class WorkspaceManager: ObservableObject {
    static let shared = WorkspaceManager()

    @Published var currentDevice: ExecutorDevice?
    @Published var activeWorkspaces: [ExecutorWorkspace] = []

    private let zmemoryClient: ZMemoryClient
    private let fileManager = FileManager.default
    private var heartbeatTimer: Timer?

    func registerDevice() async throws -> ExecutorDevice
    func createWorkspace(for task: AITask, agent: AIAgent) async throws -> ExecutorWorkspace
    func setupWorkspaceDirectories(workspace: ExecutorWorkspace) async throws
    func cloneRepository(workspace: ExecutorWorkspace) async throws
    func updateWorkspaceProgress(id: String, phase: String, progress: Int) async throws
    func cleanupWorkspace(id: String) async throws
    func archiveWorkspace(id: String) async throws -> URL

    private func startHeartbeat()
    private func stopHeartbeat()
}
```

---

## 📊 Phase 4: ZFlow Web Monitoring

### Location
- **Base Path**: `/Users/zhiruifeng/Workspace/dev/ZephyrOS/apps/zflow`

### Components to Create
1. **ExecutorDashboard** - Overview of all devices
2. **WorkspaceMonitor** - Real-time workspace tracking
3. **EventViewer** - Event logs and timeline
4. **ArtifactBrowser** - Browse generated files
5. **MetricsCharts** - Performance visualization

---

## 🚀 Implementation Timeline

### Week 1: Database & Backend Foundation
- ✅ Create database schema
- [ ] Apply schema to Supabase
- [ ] Create validation schemas
- [ ] Create repository layer
- [ ] Create service layer

### Week 2: Backend API Routes
- [ ] Device management APIs
- [ ] Workspace management APIs
- [ ] Task assignment APIs
- [ ] Event logging APIs
- [ ] Artifact & metrics APIs

### Week 3: Swift Client
- [ ] Create Swift models
- [ ] Extend ZMemoryClient
- [ ] Create WorkspaceManager
- [ ] Terminal integration
- [ ] File monitoring

### Week 4: Integration & Testing
- [ ] End-to-end testing
- [ ] ZFlow monitoring UI
- [ ] Documentation
- [ ] Performance optimization

---

## 📝 Next Immediate Steps

1. **Apply Schema to Supabase**
   ```bash
   cd /Users/zhiruifeng/Workspace/dev/ZephyrOS
   supabase db push
   ```

2. **Create Validation Schemas**
   - Create `lib/validation/executor-schemas.ts`

3. **Create Repository Layer**
   - Create `lib/database/repositories/executor-repository.ts`

4. **Create Service Layer**
   - Create `lib/services/executor-service.ts`

5. **Create First API Route**
   - Create `app/api/executor/devices/route.ts`
   - Test device registration

---

## 🎯 Success Criteria

- ✅ Database schema applied and tested
- ✅ All API routes functional
- ✅ Swift client can register device
- ✅ Swift client can create workspaces
- ✅ Events logged successfully
- ✅ Real-time monitoring in ZFlow
- ✅ Full end-to-end task execution

---

## 📚 References

- Database Schema: `/Users/zhiruifeng/Workspace/dev/ZephyrOS/supabase/executor_schema.sql`
- Development Guidelines: `/Users/zhiruifeng/Workspace/dev/ZephyrOS/apps/zmemory/DEVELOPMENT_GUIDELINES.md`
- Architecture Design: `/Users/zhiruifeng/Workspace/dev/ZephyrOS-Executor/AGENT_WORKSPACE_DESIGN.md`
