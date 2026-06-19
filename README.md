# ObjectManager

Sourcemod framework that allows easily wrapping entities with StringMaps so that they can be accessed anywhere and given custom properties.

Requires ilib and tf2attributes to compile
ilib can be found here: https://github.com/Ivory42/ilib

## Essentials
Because this framework utilizes ilib, the following objects are frequently used:
  - `FObject` - Enum struct meant to wrap entities
  - `FClient` - Enum struct meant to wrap clients
  - `FTimer` - Enum struct meant to act as a timer against `GetGameTime()`
  - `FVector` - Enum struct for vectors
  - `FRotator` Enum struct for angles
  - `FTransform` Enum struct for holding a position (vector), rotation (rotator) and velocity (vector)

### Methodmaps

 - `FEntityStatics` methodmap used for creating and maintaining entities
	- `CreateEntity` - Wraps the native `CreateEntityByName` sourcemod function and returns an `ABaseEntity` object
	- `FinishSpawningEntity` - Takes a created `ABaseEntity` and calls `Activate` along with `DispatchSpawn`. This will also register the entity for garbage collection.
	- `EnableEntityTick` - Takes a spawned `ABaseEntity` and hooks a tick function to it. The tick rate can be determined with this native
	- `DisableEntityTick` - Takes an `ABaseEntity` and disables the given tick callback
	- `SetValidationProperty` - Takes a spawned `ABaseEntity` and applies a custom validation property.
		- This property acts as a tag and can be accessed with `IsEntityOfType` to allow for """casting""" between entities.
			- This is obviously not a real cast, just an alternative to indexing an entity with a bool array
			- There is no limit to the number of validation properties a single entity is allowed to have
	- `RegisterEntity` - Takes an `FObject` entity and registers it for garbage collection. Returns an `ABaseEntity` object
	- `GetEntity` - Takes an `FObject` entity and returns an `ABaseObject` if it is already registered
	- `GetEntityFromIndex` - Takes an entity index and returns an `ABaseObject` if the entity is registered
	- `GetClient` - Takes an `FClient` object and returns an `AClient` object
	- `GetClientFromIndex` - Takes an entity index for a client and returns an `AClient` object
	- `GetConnectedClients` - Returns an `ArrayList` of all the currently connected clients as `AClient` objects

 - `FGameState` methodmap used for storing global properties that are not tied to a specific entity, but you may want to be accessed by other plugins
	- `SetGlobalProperty` - Stores a property in the global state
	- `GetGlobalProperty` - Returns the value of a property that was previously stored in the global state
	- `SetGlobalPropertyString` - Stores a property as a string in the global state
	- `GetGlobalPropertyString` - Returns a string value from a global property

## Best Practices
This framework utilizes a lot of handles and attempts to create a pseudo garbage collector. Any handles created through this framework will be freed and closed upon the entity being deleted. In the case of clients, no manual management needs to be done - clients are automatically registered and removed upon joining and disconnecting, respectively.

The general naming convention is as follows:
  - Any entities wrapped with a StringMap are prefixed with `A`, such as `ABaseEntity`
  - Any general purpose methodmaps are prefixed with `F`, such as `FEntityStatics`
  - Any handle that is subclassing the base StringMap object is prefixed with `S`, such as `SObjectMap`
  - Rarely, methodmaps used to wrap entities that are NOT intended to be persistent, are prefixed with `U`, such as `UObject`
  - Any other objects are prefixed with `F`

When utilizing the StringMaps in this framework for entities, it is highly recommended to treat custom properties as a tagging system to prevent different entity types from using the same properties. Prefixing the names of StringMap properties with the name of the entity type can resove this. I.e., if you have a grenade entity, you may use a property such as `MyGrenadeEntity.BlastRadius` in the StringMap. These can be set and pulled through `GetObjectProp` and `SetObjectProp` in the `ABaseEntity`

An example of this is as follows (assuming the entity index is already registered):
```
ABaseEntity grenade = FEntityStatics.GetEntityFromIndex(entityId);
if (grenade.GetObjectProp("MyGrenadeEntity.IsGrenade"))
{
	grenade.SetObjectPropFloat("MyGrenadeEntity.BlastRadius", 200.0);
	grenade.SetObjectPropFloat("MyGrenadeEntity.BlastDamage", 150.0);
}

```
Note that these properties are meaningless until you implement them somewhere else in your code, these properties do not correlate to any netprops or datamaps

To register an entity and call it elsewhere in your code, the following can be done:
```
void SomeFunction(int entityId)
{
	FObject entity;
	entity = ConstructObject(entityId);
	ABaseEntity myEntity = FEntityStatics.RegisterEntity(entity);
	FEntityStatics.SetValidationProperty(myEntity, "BaseEntity.MyCustomEntity"); // Tags this entity with a validation property that we can check later
}
...
void SomeOtherFunction(int entityId)
{
	ABaseEntity myEntity = FEntityStatics.GetEntityFromIndex(entityId);
	if (myEntity)
	{
		// You now have the same entity if the index matches, if you want to make sure this is the entity you are looking for, you can use validation properties
		if (IsEntityOfType(myEntity, "BaseEntity.MyCustomEntity")
		{
			// Now only execute code on entities which are tagged `BaseEntity.MyCustomEntity`
		}
	}
}
```

### Inheriting from ABaseEntity
It can be much easier to wrap most of the functionality of this framework by subclassing `ABaseEntity`. This can be done to apply methodmap properties/functions to more easily manipulate entities.

An example of doing this with proper validation is as follows:
```
methodmap AMyGrenade < ABaseEntity
{
	// Set any arbitrary properties with `SetObjectProp`
	property float CustomDamage
	{
		public set(float value) { this.SetObjectPropFloat("MyGrenadeEntity.BlastDamage", value); }
		public get() { return this.GetObjectPropFloat("MyGrenadeEntity.BlastDamage"); }
	}

	// Access expected netprops/datamaps with `GetProp` or `SetProp`
	property float Damage
	{
		public set(float value) { this.SetPropFloat(Prop_Send, "m_flDamage", value); }
		public get() { return this.GetPropFloat(Prop_Send, "m_flDamage"); }
	}

	public bool ValidGrenade()
	{
		return IsEntityOfType(this, "Entity.MyGrenadeEntity");
	}
}

void SomeFunction(AClient client)
{
	// Create our grenade as a `tf_projectile_pipe` then set the owner as the client's FObject with GetObject() and set the validation property
	AMyGrenade grenade = view_as<AMyGrenade>(FEntityStatics.CreateEntity("tf_projectile_pipe", client.GetObject(), "Entity.MyGrenadeEntity"));
	if (grenade)
	{
		// Set our custom properties
		grenade.CustomDamage = 200.0;

		// Set our netprop for m_flDamage
		grenade.Damage = 200.0;

		// Now we can get a transform (position, rotation, velocity) and spawn the grenade
		FTransform spawn;
		spawn.Position = client.GetEyePosition();
		spawn.Rotation = client.GetEyeAngles();
		spawn.Velocity = client.GetEyeAngles().GetForwardVector();
		spawn.Velocity.Scale(1100.0);

		// Calls DispatchSpawn, Activate, and registers the entity for garbage collection
		FEntityStatics.FinishSpawningEntity(grenade, spawn);

		// Now we can hook the grenade to see when it touches a client
		SDKHook(grenade.Get(), SDKHook_TouchPost, OnGrenadeTouch);
	}
}

// Now we can access this same grenade object anywhere else the entity index is present
void OnGrenadeTouch(int entityId, int otherId)
{
	// Check if this is our grenade type
	AMyGrenade grenade = view_as<AMyGrenade>(FEntityStatics.GetEntityFromIndex(entityId));
	if (grenade.ValidGrenade()) // Our defined method which uses `IsEntityOfType` to check if this entity is what we want it to be
	{
		// Check if our overlapped entity is a client
		AClient target = FEntityStatics.GetClientFromIndex(otherId);
		if (target) // If this index is a client, it will return a valid handle
		{
			// Now we can access our custom damage property to deal damage
			float damage = grenade.CustomDamage;

			int ownerId = grenade.GetOwner().Get();
			SDKHooks_TakeDamage(target.Get(), grenade.Get(), ownerId, damage, DMG_BLAST);
		}
	}
}
```

It is not recommended to set anything subclassing `ABaseEntity` as a property on an entity, as these handles can easily be lost track of. Instead, utilize the entity's `FObject` reference and store that as a property. `FObject` stores an entity's reference the same way as `EntIndexToEntReference`.
```
void SomeFunction(ABaseEntity myEntity, ABaseEntity otherEntity)
{
	FObject reference;
	reference = otherEntity.GetObject();

	// SetObjectPropEnt accepts `FObject` as a value
	myEntity.SetObjectPropEnt("Entity.MyCustomProperty", targetEntity);
}
```

If you do store handles on an entity object, make sure to always close them under the `EntManager_OnEntityDestroyed` forward
```
public void EntManager_OnEntityDestroyed(ABaseEntity entity)
{
	Handle myHandle = entity.GetObjectProp("Entity.SomeHandleProperty");
	if (myHandle)
	{
		delete myHandle;
	}
}
```