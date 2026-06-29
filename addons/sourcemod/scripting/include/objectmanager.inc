#include <ilib>
#include <ilib/objects/shared>
#include <tf2_stocks>
#include <sdkhooks>

#if defined _ilib_manager_included
 #endinput
#endif
#define _ilib_manager_included

static APersistentObject WorldSpawn; // Entity 0 or worldspawn

typeset FEntityCB
{
	function void (APersistentObject entity);
}

// This is deprecated
enum struct FEntityProps
{
	Function TickFunction; // Entity tick callback function
	Handle CallingPlugin; // Plugin handling this entity's callback functions
}

/**
 * Base entity object for wrapping game entities. These can be created from scratch or through templates on the server. Always make sure to register created entities
 * with the global entity list via `FEntityStatics.RegisterEntity` if using the constructor. If spawning through `FEntityStatics.CreateEntity` then it will be registered automatically.
 * 
 * Do NOT use `delete` with these objects. Killing the entity associated will trigger a forward to `EntManager_OnEntityDestroyed` where any used handles associated can be
 * freed up. This handle will be cleared automatically after the forward is finished.
 */
methodmap ABaseEntity < APersistentObject
{
	public ABaseEntity(FObject actor, char[] template)
	{
		APersistentObject entity = new APersistentObject(actor);
		entity.SetObjectPropString("Entity.EntTemplate", template);
		entity.SetObjectProp("Entity.ValidEntityObject", true);
		//entity.SetObjectPropString("Entity.ValidationProperty", validation);

		return view_as<ABaseEntity>(entity);
	}

	// Stores combined properties for entity callbacks
	public void SetCallbackProps(FEntityProps props) { this.SetArray("Entity.CallbackProperties", props, sizeof FEntityProps); }

	// Gets the combined properties for entity callbacks
	public FEntityProps GetCallbackProps()
	{ 
		FEntityProps props;
		this.GetArray("Entity.CallbackProperties", props, sizeof FEntityProps);

		return props;
	}

	property ArrayList ValidationProps
	{
		public get() { return view_as<ArrayList>(this.GetObjectProp("Entity.ValidationPropertyList")); }
	}

	property PrivateForward TickCallbacks
	{
		public set(PrivateForward value) { this.SetObjectProp("Entity.TickFunctions", value); }
		public get() { return view_as<PrivateForward>(this.GetObjectProp("Entity.TickFunctions")); }
	}

	// How frequently this entity ticks, if enabled
	property float TickRate
	{
		public set(float rate) { this.SetObjectPropFloat("Entity.TickRate", rate); }
		public get() { return this.GetObjectPropFloat("Entity.TickRate"); }
	}

	// Whether or not this entity ticks
	property bool CanTick
	{
		public set(bool value)	{ this.SetObjectProp("Entity.CanTick", value); }
		public get() { return this.GetObjectProp("Entity.CanTick"); }
	}

	// Next GameTime when this entity will tick
	property float NextTickTime
	{
		public set(float value) { this.SetObjectPropFloat("Entity.LastTick", value); }
		public get() { return this.GetObjectPropFloat("Entity.LastTick"); }
	}

	// Custom health property
	property int Health
	{
		public set(int health) { this.SetObjectProp("Entity.CurrentHealth", health); }
		public get() { return this.GetObjectProp("Entity.CurrentHealth"); }
	}

	property int MaxHealth
	{
		public set(int health) { this.SetObjectProp("Entity.MaxHealth", health); }
		public get() { return this.GetObjectProp("Entity.MaxHealth"); }
	}

	// Gets the template of this entity
	public void GetEntityTemplate(char[] buffer, int size)
	{
		this.GetObjectPropString("Entity.EntTemplate", buffer, size); 
	}

	public ArrayList GetValidationProperties()
	{
		return this.ValidationProps;
	}
}

methodmap FEntityStatics
{
	/* Creates a base entity with the given classname but does not spawn it
	*
	* @param classname      Classname of the entity to create
	* @param owner          Entity that will own this object
	* 
	* @return	`ABaseEntity` wrapping the created entity. (Use `FObjectStatics.FinishSpawningObject` to spawn)
	*/
	public static native ABaseEntity CreateEntity(const char[] classname, any owner[sizeof FObject] = {}, const char[] validation = "");

	/* Creates a base entity from the given KeyValues template name. See (configs/objects/templates/) for available templates.
	* 	This is a planned feature and currently does nothing
	*
	* @param classname      Classname of the entity to create
	* @param owner          Entity that will own this object
	* 
	* @return	`ABaseEntity` wrapping the created entity. (Use `FObjectStatics.FinishSpawningObject` to spawn)
	*/
	public static native ABaseEntity CreateEntityFromTemplate(const char[] template, any owner[sizeof FObject] = {});

	/* Sets the validation property for this entity. Validation properties are the equivalent to setting an indexed boolean on an entity
	* to determine whether or not the entity is what we want it to be. i.e, If we are modifying a grenade, `bool IsGrenade[2049]` would be used to
	* check if an entity is what we want it to be.
	* Here we just apply a property which can be checked with `IsEntityOfType`
	*
	* @param entity		Entity to set validation property on
	* @param property	Property name to add as a validation property
	*
	* @note Without a defined validation function, this wont be useful. Remember to define proper validation functions for any entity subclasses.
	*/
	public static native void SetValidationProperty(ABaseEntity entity, const char[] property);
	
	/* Spawns a created entity in the world and registers it with the global object list
	* 
	* @param entity			Entity to spawn
	* @param spawn			Spawn transform to teleport this entity to
	*/
	public static native void FinishSpawningEntity(ABaseEntity entity, any spawn[sizeof FTransform]);

	/* Registers an entity with the object manager for later use
	*
	* @param entity			Entity to register and store
	*
	* @return	`ABaseEntity` wrapping the entity
	*/
	public static native ABaseEntity RegisterEntity(any entity[sizeof FObject]);

	/* Registers a client with the object manager for later use
	*
	* @param client		Client to register and store
	*
	* @return	`AClient` wrapping the entity
	*/
	public static native AClient RegisterClient(any client[sizeof FClient]);

	/* Returns the calculated max health of the given client
	*
	* @param client		Client to get max health of
	*
	* @return	Calculated max health from SDKHooks_GetMaxHealth
	*/
	public static native int GetClientMaxHealth(AClient client);

	/* Returns the base max health of the given client
	*
	* @param client		Client to get base health of
	*
	* @return	Base max health from SDKHooks_GetMaxHealth
	*/
	public static native int GetClientBaseHealth(AClient client);

	/* Sets an additive max health value for the given client
	* @note This does not set the max health, but adds to the player's current base max health
	*
	* @param client		Client to set max health for
	* @param health		Additive max health value to set
	*/
	public static native void SetClientMaxHealthAdditive(AClient client, int health);

	/* Returns the additive max health value of the given client
	*
	* @param client		Client to get additive max health of
	*
	* @return	Additive max health for this client
	*/
	public static native int GetClientMaxHealthAdditive(AClient client);

	/* Retrieves an entity that has been previously registered with the global object list
	*
	* @param entity			FObject to pull from the list
	*
	* @return	`ABaseEntity` wrapping the entity
	*/
	public static native ABaseEntity GetEntity(any entity[sizeof FObject]);

	/* Retrieves an entity that has been previously registered with the global object list. Uses an entity index instead of struct
	*
	* @param entityIndex		Entity index to pull from list
	*
	* @return	`ABaseEntity` wrapping the entity
	*/
	public static native ABaseEntity GetEntityFromIndex(int entityIndex);

	/* Retrieves a client that has been previously registered with the global object list
	*
	* @param client		FClient to pull from the list
	*
	* @return	`AClient` wrapping the entity
	*/
	public static native AClient GetClient(any client[sizeof FClient]);

	/* Retrieves a client that has been previously registered with the global object list. Uses a client index instead of struct
	*
	* @param clientIndex		Client index to pull from list
	*
	* @return	`AClient` wrapping the entity
	*/
	public static native AClient GetClientFromIndex(int clientIndex);

	/* Kills and invalidates an entity that has been previously registered with the global object list
	* @note This does NOT kill any other objects set in this entity's properties. If you created other handles and assigned them as properties to an object
	* 		make sure to clear those handles in `EntManager_OnEntityDestroyed`!
	*
	* @param entity			Entity to remove
	*/
	public static native void DestroyEntity(ABaseEntity entity);

	/* Enables tick events on the given entity (not the same as think). Use sparingly and only when absolutely necessary
	*
	* @param entity			Entity to enable tick on
	* @param callback		Tick function for this entity (@note This function MUST be public, otherwise it will not be callable from the API)
	* @param tickrate		Rate at which this entity should tick (0.0 = every frame)
	*
	* @note: This only works with registered entities; if called on an entity that is not registered, it will be killed and invalidated to prevent memory leaks
	*/
	public static native void EnableEntityTick(ABaseEntity entity, FEntityCB callback, float tickrate = 0.0);

	/* Disables the given tick hook on a ticking entity.
	*
	* @param entity			Entity to disable tick on
	* @param callback		Callback function to disable
	*/
	public static native void DisableEntityTick(ABaseEntity entity, FEntityCB callback);

	/* Checks if the given object is valid and not null
	* This is deprecated and should not be used. Checking if the handle is not null should be sufficient.
	*
	* @param entity			Entity object to validate
	*
	* @return	True if the handle is not null and the entity is valid; false otherwise.
	*/
	public static native bool IsValid(ABaseEntity entity);

	// Returns an arraylist of all the currently connected players. Players are stored as `AClient` in the arraylist. Do NOT close this handle.
	public static native ArrayList GetConnectedClients();
}

methodmap FGameState
{
	//public static native void SetPersistentProperty(APersistentObject entity, const char[] property, any value);
	//public static native any GetPersistentProperty(APersistentObject entity, const char[] property);

	public static native void SetGlobalProperty(const char[] property, any value);
	public static native any GetGlobalProperty(const char[] property);

	public static native void SetGlobalString(const char[] property, const char[] value);
	public static native void GetGlobalString(const char[] property, char[] value, int size);
}

// Returns the worldspawn (entity 0) as a persistent object
stock APersistentObject GetWorldSpawn()
{
	if (!WorldSpawn)
	{
		FObject world;
		world.SetReference(0);
		WorldSpawn = new APersistentObject(world);
	}
	return WorldSpawn;
}

// Casts to ABaseEntity - Only use this if the object is guaranteed to exist.
stock ABaseEntity ValidObject(APersistentObject entity)
{
	if (!entity)
	{
		return null;
	}

	ABaseEntity actor = null;
	if (entity.GetObjectProp("Entity.ValidEntityObject"))
	{
		actor = view_as<ABaseEntity>(entity);
	}

	return actor;
}

stock bool IsEntityOfType(ABaseEntity entity, const char[] validationType)
{
	if (entity)
	{
		ArrayList list = entity.GetValidationProperties();
		if (list && list.FindString(validationType) != -1)
		{
			return true;
		}
	}

	return false;
}

/** Called when an entity is registered in the global entity list.
 * 
 * @param entity			ABaseEntity that was registered
 * @param template			If using a template, the name of the template registered
 */
forward void EntManager_OnEntityRegistered(ABaseEntity entity, const char[] template);

/** Called when a client is registered in the global client list.
 * 
 * @param client			AClient that was registered
 */
forward void EntManager_OnClientRegistered(AClient client);

/** Called when a client is about to be removed from the client list.
 * @note The client has not yet been removed until after this call is finished. It is safe to access properties in this callback.
 * 
 * @param client			AClient that was removed
 */
forward void EntManager_OnClientRemoved(AClient client);

/** Called when a valid entity is destroyed.
 * @note The entity has not yet been removed from the global entity list until after this function is completed. It is safe to access properties in this callback.
 * 
 * @param entity			ABaseEntity that was destroyed
 */
forward void EntManager_OnEntityDestroyed(ABaseEntity entity);

stock void PlayWeaponSequence(AClient client, int sequence, float duration = 2.5)
{
	FObject vm;
	vm = client.GetPropEnt(Prop_Send, "m_hViewModel");
	if (vm.Valid())
	{
		float playback = vm.GetPropFloat(Prop_Send, "m_flPlaybackRate");
		if (playback > 1.0)
		{
			vm.SetPropFloat(Prop_Send, "m_flPlaybackRate", 1.0);
		}
		vm.SetProp(Prop_Send, "m_nSequence", sequence);
	}

	FObject weapon;
	weapon = client.GetPropEnt(Prop_Send, "m_hActiveWeapon");
	if (weapon.Valid())
	{
		weapon.SetPropFloat(Prop_Send, "m_flTimeWeaponIdle", GetGameTime() + duration);
	}
}