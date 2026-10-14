---
kind: knowledge
scope: review
topics: [unity, csharp, performance, security]
triggers: [Unity, C#, MonoBehaviour, ProjectSettings, asmdef]
load: whole
---

# Stack reference: Unity and C#

Loaded by the review when the repo is a Unity project (it has
`ProjectSettings/ProjectVersion.txt`). These add to the generic dimensions;
the repo's own agent instructions and `.editorconfig` win where they differ.

## Files to skip

- `*.meta` (Unity-managed; only flag a `.cs` file with no paired `.meta`)
- `*.asset`, `*.prefab`, `*.unity`, `*.fbx`, `*.png`, `*.jpg`, `*.tga`
- `Library/`, `Temp/`, `UserSettings/`

## Correctness

- Null or destroyed Unity objects; unassigned serialized fields used before `Awake`/`Start`
- Lifecycle ordering bugs (reading in `Awake` a value set in another component's `Start`)
- `Destroy` versus `DestroyImmediate`
- Wrong coordinate space (world vs local), axis, or units (degrees vs radians)
- Races in coroutines

## Performance

- Per-frame allocations in `Update`, `FixedUpdate`, `LateUpdate` and every-frame coroutines: `new`, LINQ, string concatenation, boxing
- `Camera.main`, `FindObjectOfType`, `GameObject.Find`, `GetComponent` in hot paths (cache them)
- Physics queries in `Update` without caching; `Resources.Load` in hot paths
- GPU read-backs of textures or meshes; `Instantiate`/`Destroy` that should be pooled
- Unnecessary `yield return null` in tight coroutine loops

## Security

- Inspector fields exposed `public` instead of `[SerializeField] private`

## Conventions

- `[SerializeField] private` preferred over `public` for inspector-exposed fields
- Missing `[RequireComponent]` for components that assume another component
  exists on the same GameObject
- `MonoBehaviour` event methods (`Awake`, `OnEnable`, `Start`, `Update`, etc.)
  called directly (should be via Unity's lifecycle, not manual calls)
- Calling `StopAllCoroutines` when only one coroutine should be stopped
- Using `string` overloads of `StartCoroutine`/`Invoke` (use the method-reference
  overloads instead)
- `GetComponent` in `Update` rather than cached in `Awake`/`Start`
- Using `transform.position +=` in `FixedUpdate` (use `rigidbody.MovePosition`
  for physics objects)
- Assembly definition (`asmdef`) violations: file is in a directory whose
  `asmdef` doesn't reference the types it uses, or creates a circular reference
- Editor-only code (using `UnityEditor` namespace) not guarded by `#if UNITY_EDITOR`
- Missing `null` checks after `GetComponent<T>()` where T is optional

## Tests

- Tests with no `[Test]` or `[UnityTest]` attribute (silently not run)
