#include <objectmanager>

static SObjectMap EntityList;
static SObjectMap ClientList;
static ArrayList TickingEntities;
static ArrayList UnorderedClientList;
// static StringMap PersistentProps;
static StringMap Globals;

static GlobalForward OnObjectRegistered;
static GlobalForward OnObjectDestroyed;
static GlobalForward OnClientRegistered;
static GlobalForward OnClientRemoved;

static const char EmptyTemplateName[16] = "TEMPLATE_NONE";

public Plugin myinfo =
{
	name = "[TF2] Entity Manager",
	author = "IvoryPal",
	description = "Creates a global list of entities which can be accessed and altered by other plugins.",
	version = "0.1.0",
	url = "https://github.com/Ivory42/ObjectManager"
};


/**************************
 * 
 * 
 * INITIALIZERS
 * 
 * 
 **************************/

public void OnPluginStart()
{
	EntityList = new SObjectMap();
	TickingEntities = new ArrayList();
	ClientList = new SObjectMap();
	UnorderedClientList = new ArrayList();
	// PersistentProps = new StringMap();
	Globals = new StringMap();

	OnObjectRegistered = new GlobalForward("EntManager_OnEntityRegistered", ET_Ignore, Param_Any, Param_String);
	OnObjectDestroyed = new GlobalForward("EntManager_OnEntityDestroyed", ET_Ignore, Param_Any);
	OnClientRegistered = new GlobalForward("EntManager_OnClientRegistered", ET_Ignore, Param_Any);
	OnClientRemoved = new GlobalForward("EntManager_OnClientRemoved", ET_Ignore, Param_Any);

	RegAdminCmd("sm_entmanager_dumpentities", CmdDumpEnts, ADMFLAG_BAN);
}

public void OnClientPutInServer(int clientId)
{
	AClient client = new AClient(ConstructClient(clientId));
	RegisterClient(client);

	SDKHook(clientId, SDKHook_GetMaxHealth, OnGetMaxHealth);
}

public void OnClientDisconnect(int clientId)
{
	AClient client = GetClient(ConstructClient(clientId));
	if (client)
	{
		client.SetObjectProp("Client.MaxHealthAdditive", 0);
		Call_StartForward(OnClientRemoved);
		Call_PushCell(client);
		Call_Finish();

		RemoveClient(client);

		delete client;
	}
}

Action CmdDumpEnts(int client, int args)
{
	char EntList[1024]; // Debug only, doesnt need to fit every entity

	if (ClientList)
	{
		FormatEx(EntList, sizeof EntList, "GLOBAL CLIENT LIST\n--------------------------------------------");
		StringMapSnapshot snapshot = ClientList.Snapshot();

		if (snapshot)
		{
			int length = snapshot.Length;
			ABaseEntity entity;
			char key[128];

			char entTotal[32], entString[32];
			FormatEx(entTotal, sizeof entTotal, "\nTotal clients: %d", length);
			StrCat(EntList, sizeof EntList, entTotal);

			if (length > 0)
			{
				for (int i = 0; i < length; i++)
				{
					snapshot.GetKey(i, key, sizeof key);

					if (ClientList.ContainsKey(key))
					{
						ClientList.GetValue(key, entity);

						FormatEx(entString, sizeof entString, "\nEntity: %d | Handle: %x", entity.Get(), entity);
						StrCat(EntList, sizeof EntList, entString);
					}
				}
			}

			PrintToConsole(client, EntList);
			delete snapshot;
		}
	}
	else
	{
		PrintToConsole(client, "Client list not initialized!");
	}

	if (EntityList)
	{
		FormatEx(EntList, sizeof EntList, "GLOBAL ENTITY LIST\n--------------------------------------------");
		StringMapSnapshot snapshot = EntityList.Snapshot();

		if (snapshot)
		{
			int length = snapshot.Length;
			ABaseEntity entity;
			char key[128];

			char entTotal[32], entString[32];
			FormatEx(entTotal, sizeof entTotal, "\nTotal Entities: %d", length);
			StrCat(EntList, sizeof EntList, entTotal);

			if (length > 0)
			{
				for (int i = 0; i < length; i++)
				{
					snapshot.GetKey(i, key, sizeof key);

					if (EntityList.ContainsKey(key))
					{
						EntityList.GetValue(key, entity);

						FormatEx(entString, sizeof entString, "\nEntity: %d | Handle: %x", entity.Get(), entity);
						StrCat(EntList, sizeof EntList, entString);
					}
				}
			}

			PrintToConsole(client, EntList);
			delete snapshot;
		}
	}
	else
	{
		PrintToConsole(client, "Entity list not initialized!");
	}

	if (TickingEntities)
	{
		FormatEx(EntList, sizeof EntList, "\nTICKING ENTITY LIST\n--------------------------------------------");

		int length = TickingEntities.Length;
		char entTotal[32], entString[32];
		FormatEx(entTotal, sizeof entTotal, "\nTotal Entities: %d", length);
		StrCat(EntList, sizeof EntList, entTotal);
		if (length > 0)
		{
			ABaseEntity entity;

			for (int i = 0; i < length; i++)
			{
				entity = view_as<ABaseEntity>(TickingEntities.Get(i));

				FormatEx(entString, sizeof entString, "\nEntity: %d | Handle: %x", entity.Get(), entity);
				StrCat(EntList, sizeof EntList, entString);
			}
		}

		PrintToConsole(client, EntList);
	}
	else
	{
		PrintToConsole(client, "Ticking list not initialized!");
	}

	return Plugin_Handled;
}

public void OnEntityDestroyed(int entity)
{
	if (IsValidEntity(entity) && entity > MaxClients && entity <= 2048)
	{
		ABaseEntity actor = GetEntity(ConstructObject(entity));
		if (actor)
		{
			DisableEntityTick(actor);
			actor.TickCallbacks = null;

			Call_StartForward(OnObjectDestroyed);
			Call_PushCell(actor);
			Call_Finish();

			ArrayList validation = actor.GetValidationProperties();
			if (validation)
			{
				delete validation;
			}
			RemoveEntityFromList(actor);
			//PrintToChatAll("Entity %d (%x) removed", entity, actor);

			actor.Clear();
			delete actor;
			//PrintToChatAll("(OM OnEntityDestroyed) Successfully deleted entity\nHandle = %x", actor);
		}
		actor = null;
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("FEntityStatics.CreateEntity", EntNative_CreateEntity);
	CreateNative("FEntityStatics.CreateEntityFromTemplate", EntNative_CreateFromTemplate);
	CreateNative("FEntityStatics.FinishSpawningEntity", EntNative_FinishSpawn);
	CreateNative("FEntityStatics.RegisterEntity", EntNative_RegisterEntity);
	CreateNative("FEntityStatics.RegisterClient", EntNative_RegisterClient);
	CreateNative("FEntityStatics.GetEntity", EntNative_GetEntity);
	CreateNative("FEntityStatics.GetEntityFromIndex", EntNative_GetEntityIndex);
	CreateNative("FEntityStatics.GetClient", EntNative_GetClient);
	CreateNative("FEntityStatics.GetClientFromIndex", EntNative_GetClientIndex);
	CreateNative("FEntityStatics.DestroyEntity", EntNative_Destroy);
	CreateNative("FEntityStatics.EnableEntityTick", EntNative_EnableTick);
	CreateNative("FEntityStatics.DisableEntityTick", EntNative_DisableTick);
	CreateNative("FEntityStatics.IsValid", EntNative_Valid);
	CreateNative("FEntityStatics.GetConnectedClients", EntNative_GetClients);
	CreateNative("FEntityStatics.SetValidationProperty", EntNative_ValidationProp);
	CreateNative("FEntityStatics.GetClientMaxHealth", EntNative_GetClientHealth);
	CreateNative("FEntityStatics.SetClientMaxHealthAdditive", EntNative_SetClientHealthAdditive);
	CreateNative("FEntityStatics.GetClientMaxHealthAdditive", EntNative_GetClientHealthAdditive);
	CreateNative("FEntityStatics.GetClientBaseHealth", EntNative_GetClientBaseHealth);

	//CreateNative("FGameState.SetPersistentProperty", GameState_SetPersistentProperty);
	//CreateNative("FGameState.GetPersistentProperty", GameState_GetPersistentProperty);
	CreateNative("FGameState.SetGlobalProperty", GameState_SetGlobalProperty);
	CreateNative("FGameState.GetGlobalProperty", GameState_GetGlobalProperty);
	CreateNative("FGameState.SetGlobalString", GameState_SetGlobalString);
	CreateNative("FGameState.GetGlobalString", GameState_GetGlobalString);

	return APLRes_Success;
}

/**************************
 * 
 * 
 * NATIVE FUNCTIONS
 * 
 * 
 **************************/

any EntNative_CreateEntity(Handle plugin, int args)
{
	char classname[256], validation[128];
	FObject owner;

	GetNativeString(1, classname, sizeof classname);
	GetNativeArray(2, owner, sizeof FObject);
	GetNativeString(3, validation, sizeof validation);

	FObject entity;
	entity = FGameplayStatics.CreateObjectDeferred(classname);

	return CreateBaseEntity(entity, owner, validation);
}

any EntNative_CreateFromTemplate(Handle plugin, int args)
{
	// WIP
	ABaseEntity entity = CreateTemplatedEntity(EmptyTemplateName);

	return entity;
}

any EntNative_FinishSpawn(Handle plugin, int args)
{
	ABaseEntity entity = view_as<ABaseEntity>(GetNativeCell(1));
	
	FTransform spawn;
	GetNativeArray(2, spawn, sizeof FTransform);

	FGameplayStatics.FinishSpawn(entity.GetObject(), spawn);

	RegisterEntity(entity);
	return 0;
}

any EntNative_RegisterEntity(Handle plugin, int args)
{
	FObject entity;
	GetNativeArray(1, entity, sizeof FObject);

	if (!entity.Valid())
	{
		char name[64];
		GetPluginFilename(plugin, name, sizeof name);
		LogMessage("Plugin %s attempted to register an invalid entity (%d). Aborting.", name, entity.Get());
		return 0;
	}

	ABaseEntity actor = CreateBaseEntity(entity, ConstructObject(0), "");

	return RegisterEntity(actor);
}

any EntNative_RegisterClient(Handle plugin, int args)
{
	FClient clientRef;
	GetNativeArray(1, clientRef, sizeof FClient);

	AClient client = new AClient(clientRef);

	return RegisterClient(client);
}

any EntNative_GetEntity(Handle plugin, int args)
{
	FObject entity;
	GetNativeArray(1, entity, sizeof FObject);

	return GetEntity(entity);
}

any EntNative_GetEntityIndex(Handle plugin, int args)
{
	int index = GetNativeCell(1);
	FObject entity;
	entity = ConstructObject(index);

	return GetEntity(entity);
}


any EntNative_GetClient(Handle plugin, int args)
{
	FClient clientRef;
	GetNativeArray(1, clientRef, sizeof FClient);

	return GetClient(clientRef);
}

any EntNative_GetClientIndex(Handle plugin, int args)
{
	int index = GetNativeCell(1);
	FClient client;
	client = ConstructClient(index);

	return GetClient(client);
}

any EntNative_Destroy(Handle plugin, int args)
{
	ABaseEntity actor = GetNativeCell(1);
	if (actor)
	{
		char name[64];
		GetPluginFilename(plugin, name, sizeof name);
		if (0 <= actor.Get() < MaxClients)
		{
			LogMessage("Plugin %s attempted to kill a client or the world (%d). This is probably a mistake. Aborting.", name, actor.Get());
			return 0;
		}
		actor.GetObject().Kill();
	}

	return 0;
}

any EntNative_EnableTick(Handle plugin, int args)
{
	ABaseEntity entity = view_as<ABaseEntity>(GetNativeCell(1));
	Function callbackFunc = GetNativeFunction(2);
	float tickrate = GetNativeCell(3);

	if (!entity.TickCallbacks)
	{
		entity.TickCallbacks = new PrivateForward(ET_Ignore, Param_Cell);
	}

	entity.TickCallbacks.AddFunction(plugin, callbackFunc);

	entity.TickRate = tickrate;

	// Do not hook unregistered entities
	if (!IsEntInList(entity))
	{
		delete entity.TickCallbacks;
		FObjectStatics.RemoveObject(entity);
		return 0;
	}

	if (TickingEntities && !entity.CanTick)
		TickingEntities.Push(entity);

	entity.CanTick = true;

	return 0;
}

any EntNative_DisableTick(Handle plugin, int args)
{
	ABaseEntity entity = view_as<ABaseEntity>(GetNativeCell(1));
	Function callbackFunc = GetNativeFunction(2);

	UnHookEntityTick(entity, plugin, callbackFunc);
	
	//DisableEntityTick(entity);

	return 0;
}

any EntNative_Valid(Handle plugin, int args)
{
	ABaseEntity entity = view_as<ABaseEntity>(GetNativeCell(1));

	if (entity)
	{
		return entity.Valid();
	}

	return false;
}

any EntNative_GetClients(Handle plugin, int args)
{
	return UnorderedClientList;
}

any EntNative_ValidationProp(Handle plugin, int args)
{
	ABaseEntity entity = view_as<ABaseEntity>(GetNativeCell(1));
	char propertyName[64];
	GetNativeString(2, propertyName, sizeof propertyName);

	if (strlen(propertyName) > 0)
	{
		ArrayList validations = entity.GetValidationProperties();
		if (validations && !IsEntityOfType(entity, propertyName)) // If we are already of this type, do not add a duplicate entry
		{
			validations.PushString(propertyName);
		}
		else if (!validations) // If we do not already have a validation array, lets create one
		{
			validations = new ArrayList(128);
	
			validations.PushString(propertyName);
			entity.SetObjectProp("Entity.ValidationPropertyList", validations);
		}
	}
	return 0;
}

any EntNative_GetClientHealth(Handle plugin, int args)
{
	AClient client = view_as<AClient>(GetNativeCell(1));
	return client.GetObjectProp("Client.CalculatedMaxHealth");
}

any EntNative_GetClientBaseHealth(Handle plugin, int args)
{
	AClient client = view_as<AClient>(GetNativeCell(1));
	return client.GetObjectProp("Client.BaseMaxHealth");
}

any EntNative_GetClientHealthAdditive(Handle plugin, int args)
{
	AClient client = view_as<AClient>(GetNativeCell(1));
	return client.GetObjectProp("Client.MaxHealthAdditive");
}

any EntNative_SetClientHealthAdditive(Handle plugin, int args)
{
	AClient client = view_as<AClient>(GetNativeCell(1));
	int health = GetNativeCell(2);

	client.SetObjectProp("Client.MaxHealthAdditive", health);

	return 0;
}

any GameState_GetGlobalString(Handle plugin, int args)
{
	int length = 0;
	GetNativeStringLength(1, length);
	
	char[] propname = new char[length];
	GetNativeString(1, propname, length + 1);

	length = GetNativeCell(3) + 1;
	char[] value = new char[length];
	Globals.GetString(propname, value, length);

	SetNativeString(2, value, length);

	return 0;
}

any GameState_SetGlobalString(Handle plugin, int args)
{
	int length = 0;
	GetNativeStringLength(1, length);
	
	char[] propname = new char[length];
	GetNativeString(1, propname, length + 1);

	GetNativeStringLength(2, length);

	char[] value = new char[length];
	GetNativeString(2, value, length + 1);

	Globals.SetString(propname, value);

	return 0;
}

any GameState_SetGlobalProperty(Handle plugin, int args)
{
	int length = 0;
	GetNativeStringLength(1, length);
	
	char[] propname = new char[length];
	GetNativeString(1, propname, length + 1);

	any value = GetNativeCell(2);

	Globals.SetValue(propname, value);

	return 0;
}

any GameState_GetGlobalProperty(Handle plugin, int args)
{
	int length = 0;
	GetNativeStringLength(1, length);
	
	char[] propname = new char[length];
	GetNativeString(1, propname, length + 1);

	any value;
	Globals.GetValue(propname, value);

	return value;
}

/*
int Native_Test(Handle plugin, int args)
{
	int cell1 = GetNativeCell(1);
	PrintToChatAll("test: Cell 1 = %d", cell1);

	return 0;
}
*/

/**************************
 * 
 * 
 * ENTITY FUNCTIONS
 * 
 * 
 **************************/

Action OnGetMaxHealth(int entityId, int& maxHealth)
{
	Action action = Plugin_Continue;
	AClient client = GetClient(ConstructClient(entityId));
	if (client)
	{
		client.SetObjectProp("Client.BaseMaxHealth", maxHealth);
		int additive = client.GetObjectProp("Client.MaxHealthAdditive");
		if (additive > 0)
		{
			maxHealth += additive;
			action = Plugin_Changed;
		}
		client.SetObjectProp("Client.CalculatedMaxHealth", maxHealth);
	}

	return action;
}

void UnHookEntityTick(ABaseEntity entity, Handle plugin, Function func)
{
	if (entity.TickCallbacks)
	{
		entity.TickCallbacks.RemoveFunction(plugin, func);
		if (entity.TickCallbacks.FunctionCount < 1)
		{
			// Disable our entity from ticking
			DisableEntityTick(entity);
		}
	}
}

void DisableEntityTick(ABaseEntity entity)
{
	if (TickingEntities)
	{
		int index = GetTickingEntityIndex(entity);
		if (index != -1)
		{
			TickingEntities.Erase(index);
		}
	}
	entity.CanTick = false;

	if (entity.TickCallbacks)
	{
		delete entity.TickCallbacks;
	}
}

ABaseEntity GetEntity(FObject entity)
{
	ABaseEntity actor = null;
	if (EntityList.HasKey(entity))
		actor = ValidObject(EntityList.GetObject(entity));

	return actor;
}

AClient GetClient(FClient clientRef)
{
	AClient client = null;
	if (ClientList.HasKey(clientRef.GetObject()))
		client = view_as<AClient>(ClientList.GetObject(clientRef.GetObject()));

	return client;
}

ABaseEntity RegisterEntity(ABaseEntity entity)
{
	char template[64];
	entity.GetEntityTemplate(template, sizeof template);

	if (EntityList)
	{
		if (!IsEntInList(entity))
			EntityList.SetObjectValue(entity.GetObject(), entity);

		Call_StartForward(OnObjectRegistered);
		Call_PushCell(entity);
		Call_PushString(template);
		Call_Finish();

		return entity;
	}

	// Entity is already registered, remove this extra handle
	delete entity;
	return null;
}

void RegisterClient(AClient client)
{
	if (ClientList)
	{
		// Only set the value if this client is not yet registered
		if (!IsClientInList(client))
			ClientList.SetObjectValue(client.GetObject(), client);

		Call_StartForward(OnClientRegistered);
		Call_PushCell(client);
		Call_Finish();
	}

	if (UnorderedClientList && CheckDuplicateClient(client))
	{
		UnorderedClientList.Push(client);
	}
}

bool CheckDuplicateClient(AClient client)
{
	for (int i = 0; i < UnorderedClientList.Length; i++)
	{
		AClient check = UnorderedClientList.Get(i);
		if (check != client)
		{
			continue;
		}
		if (check == client) // This client is already in our list, return false
		{
			return false;
		}
	}

	return true; // If our client is not found, return true
}

ABaseEntity CreateBaseEntity(FObject base, FObject owner = {}, const char[] validation)
{
	char template[16];
	FormatEx(template, sizeof template, EmptyTemplateName);
	ABaseEntity entity = new ABaseEntity(base, template);
	if (owner.Valid())
	{
		entity.SetOwner(owner);
	}

	ArrayList validations = new ArrayList(128);
	if (strlen(validation) > 0)
	{
		validations.PushString(validation);
	}
	entity.SetObjectProp("Entity.ValidationPropertyList", validations);

	return entity;
}

ABaseEntity CreateTemplatedEntity(const char[] template)
{
	if (StrEqual(template, EmptyTemplateName))
	{
		return null; // Cannot create an entity with an invalid template
	}

	// WIP
	return null;
}

public void OnGameFrame()
{
	if (TickingEntities)
	{
		int length = TickingEntities.Length;
		ABaseEntity entity;

		if (length < 1)
			return;

		for (int i = 0; i < length; i++)
		{
			// not sure how this is happening but it keeps erroring
			if (i >= length)
				continue;

			entity = view_as<ABaseEntity>(TickingEntities.Get(i));
			if (!entity)
			{
				// Somehow an entity was deleted without this plugin doing anything. Remove from list here.
				DisableEntityTick(entity);
				continue;
			}
			if (entity.NextTickTime <= GetGameTime() && IsEntInList(entity))
			{
				entity.NextTickTime = GetGameTime() + entity.TickRate;

				if (entity.TickCallbacks)
				{
					Call_StartForward(entity.TickCallbacks);
					Call_PushCell(entity);

					Call_Finish();
				}

				/*
				FEntityProps props;
				props = entity.GetCallbackProps();

				if (props.CallingPlugin)
				{
					Call_StartFunction(props.CallingPlugin, props.TickFunction);
					Call_PushCell(entity);

					Call_Finish();
				}
				*/
			}
		}
	}
}

/**************************
 * 
 * 
 * HELPER FUNCTIONS
 * 
 * 
 **************************/

bool IsEntInList(ABaseEntity entity)
{
	if (EntityList)
	{
		return EntityList.HasKey(entity.GetObject());
	}

	return false;
}

bool IsClientInList(AClient client)
{
	if (ClientList)
	{
		return ClientList.HasKey(client.GetObject());
	}

	return false;
}

int GetTickingEntityIndex(ABaseEntity entity)
{
	if (TickingEntities)
	{
		int length = TickingEntities.Length;

		for (int i = 0; i < length; i++)
		{
			ABaseEntity test = view_as<ABaseEntity>(TickingEntities.Get(i));

			if (test == entity)
				return i;
		}
	}

	return -1;
}

void RemoveEntityFromList(ABaseEntity entity)
{
	if (EntityList)
	{
		if (EntityList.HasKey(entity.GetObject()))
		{
			//PrintToChatAll("Entity List has entity: %d (%x)", entity.Get(), entity);
			EntityList.RemoveObjectValue(entity.GetObject());
			//PrintToChatAll("Entity List Removed Entity: %d (%x) | Handle in list = %x", entity.Get(), entity, EntityList.GetObject(entity.GetObject()));
		}
	}

	if (TickingEntities)
	{
		int index = GetTickingEntityIndex(entity);
		if (index != -1)
		{
			entity.CanTick = false;
			TickingEntities.Erase(index);
		}
	}
}

void RemoveClient(AClient client)
{
	if (ClientList)
	{
		if (ClientList.HasKey(client.GetObject()))
		{
			ClientList.RemoveObjectValue(client.GetObject());
		}
	}

	if (UnorderedClientList)
	{
		for (int i = 0; i < UnorderedClientList.Length; i++)
		{
			if (client == UnorderedClientList.Get(i))
			{
				UnorderedClientList.Erase(i);
			}
		}
	}
}
