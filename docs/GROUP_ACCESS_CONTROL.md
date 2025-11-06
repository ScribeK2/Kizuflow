# Group Access Control Documentation

## Overview

Kizuflow implements a hierarchical group-based access control system that allows administrators to organize workflows into groups and control which users can access them.

## Access Control Rules

### Admin Users
- **Groups**: See all groups in the system
- **Workflows**: See all workflows regardless of group assignment
- **Management**: Can create, edit, and delete groups
- **User Assignment**: Can assign groups to any user

### Editor Users
- **Groups**: See only groups they are assigned to (plus Uncategorized)
- **Workflows**: See workflows in assigned groups + their own workflows + all public workflows
- **Management**: Cannot manage groups (admin-only)
- **Assignment**: Groups are assigned by administrators

### Regular Users
- **Groups**: See only groups they are assigned to (plus Uncategorized)
- **Workflows**: See workflows in assigned groups + all public workflows
- **Management**: Cannot manage groups (admin-only)
- **Assignment**: Groups are assigned by administrators

## Group Hierarchy and Inheritance

### Parent-Child Relationships
- Users assigned to a parent group automatically have access to workflows in all child groups
- Example: If a user is assigned to "Customer Support", they can see workflows in "Customer Support > Phone Support" and "Customer Support > Chat Support"

### Descendant Access
- When filtering workflows by a group, the system includes workflows from all descendant groups
- Example: Viewing "Customer Support" shows workflows in "Customer Support", "Phone Support", "Chat Support", etc.

## Special Groups

### Uncategorized Group
- **Purpose**: Default group for workflows without explicit group assignments
- **Visibility**: Always visible to all users (for backward compatibility)
- **Auto-Assignment**: New workflows without group selection are automatically assigned here
- **Migration**: Existing workflows without groups are assigned to Uncategorized during migration

## Workflow Visibility Logic

The `Workflow.visible_to(user)` scope implements the following logic:

1. **Base Scope** (role-based):
   - Admins: All workflows
   - Editors: Own workflows + public workflows
   - Users: Public workflows only

2. **Group Filtering** (if user has group assignments):
   - Include workflows in user's assigned groups (and descendants)
   - Include workflows without groups (backward compatibility)
   - Include public workflows (always accessible)
   - Include user's own workflows (for editors)

3. **No Group Assignments**:
   - Show all workflows from base scope
   - Include workflows without groups (backward compatibility)

## Group Visibility Logic

The `Group.visible_to(user)` scope implements:

1. **Admins**: All groups
2. **Other Users**: 
   - Groups they are assigned to
   - Uncategorized group (always included)

## Implementation Details

### Database Schema
- `groups`: Hierarchical structure with `parent_id` for nesting
- `group_workflows`: Many-to-many join table (workflows can belong to multiple groups)
- `user_groups`: Many-to-many join table (users can belong to multiple groups)

### Key Methods
- `Group#ancestors`: Recursive method to get all parent groups
- `Group#descendants`: Recursive method to get all child groups
- `Group#can_be_viewed_by?(user)`: Checks if user has access (direct or via ancestor)
- `Workflow#visible_to(user)`: Scope that filters workflows based on user's group assignments
- `Workflow#in_group(group)`: Scope that filters workflows by group (includes descendants)

### Performance Considerations
- Tree traversal methods (`ancestors`, `descendants`) use recursive algorithms
- For large hierarchies, consider caching or using recursive CTEs
- Controllers use `includes(:children)` to prevent N+1 queries when rendering trees
- `workflows_count` method optimized to use a single query instead of N+1

## Best Practices

1. **Group Organization**: Keep group hierarchies shallow (2-3 levels) for better performance
2. **User Assignment**: Assign users to parent groups when they need access to all children
3. **Workflow Assignment**: Assign workflows to the most specific group possible
4. **Public Workflows**: Use public flag for workflows that should be accessible to all users
5. **Migration**: Run data migration to assign existing workflows to Uncategorized before using groups

## Security Considerations

- Group management is admin-only (enforced by `before_action :ensure_admin!`)
- User-group assignment is admin-only
- Workflow visibility is enforced at the database query level (scopes)
- Circular references in group hierarchy are prevented by validation
- Maximum depth limit prevents infinite nesting

