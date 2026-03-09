-- Migration 001: Initial schema for self-hosted Shorebird Code Push
-- All tables, indexes, and constraints for the complete system.

-- Enum types
CREATE TYPE organization_type AS ENUM ('personal', 'team');
CREATE TYPE user_role AS ENUM ('owner', 'admin', 'appManager', 'developer', 'viewer');
CREATE TYPE app_collaborator_role AS ENUM ('admin', 'developer');
CREATE TYPE release_platform AS ENUM ('android', 'ios', 'linux', 'macos', 'windows');
CREATE TYPE release_status AS ENUM ('draft', 'active');

-- Users
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  display_name TEXT,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Refresh tokens (for JWT auth)
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);

-- Organizations
CREATE TABLE IF NOT EXISTS organizations (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  organization_type organization_type NOT NULL DEFAULT 'personal',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Organization memberships
CREATE TABLE IF NOT EXISTS organization_memberships (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  organization_id INTEGER NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  role user_role NOT NULL DEFAULT 'developer',
  UNIQUE(user_id, organization_id)
);

CREATE INDEX idx_org_memberships_user_id ON organization_memberships(user_id);
CREATE INDEX idx_org_memberships_org_id ON organization_memberships(organization_id);

-- Apps
CREATE TABLE IF NOT EXISTS apps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  display_name TEXT NOT NULL,
  organization_id INTEGER NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_apps_organization_id ON apps(organization_id);

-- App collaborators (per-app access without org membership)
CREATE TABLE IF NOT EXISTS app_collaborators (
  id SERIAL PRIMARY KEY,
  app_id UUID NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role app_collaborator_role NOT NULL DEFAULT 'developer',
  UNIQUE(app_id, user_id)
);

-- Channels
CREATE TABLE IF NOT EXISTS channels (
  id SERIAL PRIMARY KEY,
  app_id UUID NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  UNIQUE(app_id, name)
);

CREATE INDEX idx_channels_app_id ON channels(app_id);

-- Releases
CREATE TABLE IF NOT EXISTS releases (
  id SERIAL PRIMARY KEY,
  app_id UUID NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
  version TEXT NOT NULL,
  flutter_revision TEXT NOT NULL,
  flutter_version TEXT,
  display_name TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(app_id, version)
);

CREATE INDEX idx_releases_app_id ON releases(app_id);

-- Release platform statuses
CREATE TABLE IF NOT EXISTS release_platform_statuses (
  id SERIAL PRIMARY KEY,
  release_id INTEGER NOT NULL REFERENCES releases(id) ON DELETE CASCADE,
  platform release_platform NOT NULL,
  status release_status NOT NULL DEFAULT 'draft',
  UNIQUE(release_id, platform)
);

-- Release artifacts
CREATE TABLE IF NOT EXISTS release_artifacts (
  id SERIAL PRIMARY KEY,
  release_id INTEGER NOT NULL REFERENCES releases(id) ON DELETE CASCADE,
  arch TEXT NOT NULL,
  platform release_platform NOT NULL,
  hash TEXT NOT NULL,
  size INTEGER NOT NULL,
  storage_path TEXT NOT NULL,
  podfile_lock_hash TEXT,
  can_sideload BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(release_id, arch, platform)
);

-- Patches
CREATE TABLE IF NOT EXISTS patches (
  id SERIAL PRIMARY KEY,
  release_id INTEGER NOT NULL REFERENCES releases(id) ON DELETE CASCADE,
  number INTEGER NOT NULL,
  notes TEXT,
  metadata JSONB,
  is_rolled_back BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(release_id, number)
);

CREATE INDEX idx_patches_release_id ON patches(release_id);

-- Patch artifacts
CREATE TABLE IF NOT EXISTS patch_artifacts (
  id SERIAL PRIMARY KEY,
  patch_id INTEGER NOT NULL REFERENCES patches(id) ON DELETE CASCADE,
  arch TEXT NOT NULL,
  platform release_platform NOT NULL,
  hash TEXT NOT NULL,
  hash_signature TEXT,
  size INTEGER NOT NULL,
  storage_path TEXT NOT NULL,
  podfile_lock_hash TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(patch_id, arch, platform)
);

-- Patch-channel assignments (many-to-many)
CREATE TABLE IF NOT EXISTS patch_channels (
  id SERIAL PRIMARY KEY,
  patch_id INTEGER NOT NULL REFERENCES patches(id) ON DELETE CASCADE,
  channel_id INTEGER NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  UNIQUE(patch_id, channel_id)
);

-- Migrations tracking table
CREATE TABLE IF NOT EXISTS _migrations (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
