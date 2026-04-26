// Neo4j Vector 2.0 Schema
// This file defines constraints and indexes for the knowledge graph

// Node Labels & Constraints

// Projects
CREATE CONSTRAINT project_name IF NOT EXISTS
FOR (p:Project) REQUIRE p.name IS UNIQUE;

CREATE INDEX project_path IF NOT EXISTS
FOR (p:Project) ON (p.path);

// Files
CREATE INDEX file_path IF NOT EXISTS
FOR (f:File) ON (f.path);

// Functions
CREATE INDEX function_name IF NOT EXISTS
FOR (fn:Function) ON (fn.name);

// Classes
CREATE INDEX class_name IF NOT EXISTS
FOR (c:Class) ON (c.name);

// Concepts (theories, patterns, architectures)
CREATE CONSTRAINT concept_name IF NOT EXISTS
FOR (c:Concept) REQUIRE c.name IS UNIQUE;

// Tasks
CREATE INDEX task_id IF NOT EXISTS
FOR (t:Task) ON (t.id);

// Agents
CREATE INDEX agent_name IF NOT EXISTS
FOR (a:Agent) ON (a.name);

// Relationship Types (documented for clarity)
// File -> File: DEPENDS_ON (imports/includes)
// Function -> Function: CALLS (execution flow)
// Class -> Concept: IMPLEMENTS (maps to theory)
// Project -> Task: HAS_TASK (PM tracking)
// Agent -> Task: PERFORMS (responsibility)
// Project -> Project: RELATES_TO (cross-repo dependencies)
// Project -> Project: PART_OF (sub-projects)
// File -> Function: CONTAINS
// File -> Class: CONTAINS
