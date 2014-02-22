import("pathfinder.road", "RoadPathFinder", 3);

class CakiTTDAI extends AIController {
function ConnectTownsByRoad(townA,townB);
function FindBestStationSpotForTown(town);
function PrintFinancialStatus();
function FindPlaceForDepot(town);
function BuildRoute(ta,tb);
function Save();
function Load();
}

function CakiTTDAI::Save()
{
	//AILog.Info("Saving right now...");
	local data={};
	return data;
	//Not yet implemented...
}
function Load(data)
{
	local LoadedData=data;
}

function CakiTTDAI::FindPlaceForDepot(town)
{
	//implemented in FindBestStationSpotForTown
}

function CakiTTDAI::PrintFinancialStatus()
{
	AILog.Info("Bank: "+AICompany.GetBankBalance(AICompany.COMPANY_SELF)+" MaxLoan: "+AICompany.GetMaxLoanAmount()+" Loan: "+AICompany.GetLoanAmount());
}
function CakiTTDAI::ConnectTownsByRoad(townA,townB)
{
  /* Tell OpenTTD we want to build normal road (no tram tracks). */
  AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);

  /* Create an instance of the pathfinder. */
  local pathfinder = RoadPathFinder();

  /* Set the cost for making a turn extreme high. */
  pathfinder.cost.turn = 5000;

  /* Give the source and goal tiles to the pathfinder. */
  pathfinder.InitializePath([AITown.GetLocation(townA)], [AITown.GetLocation(townB)]);

  /* Try to find a path. */
  local path = false;
  while (path == false) {
    path = pathfinder.FindPath(100);
    this.Sleep(1);
  }

  if (path == null) {
    /* No path was found. */
    AILog.Error("pathfinder.FindPath return null");
  }

  /* If a path was found, build a road over it. */
  while (path != null) {
    local par = path.GetParent();
    if (par != null) {
      local last_node = path.GetTile();
      if (AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) == 1 ) {
        if (!AIRoad.BuildRoad(path.GetTile(), par.GetTile())) {
          /* An error occured while building a piece of road. TODO: handle it. 
           * Note that is can also be the case that the road was already build. */
        }
      } else {
        /* Build a bridge or tunnel. */
        if (!AIBridge.IsBridgeTile(path.GetTile()) && !AITunnel.IsTunnelTile(path.GetTile())) {
          /* If it was a road tile, demolish it first. Do this to work around expended roadbits. */
          if (AIRoad.IsRoadTile(path.GetTile())) AITile.DemolishTile(path.GetTile());
          if (AITunnel.GetOtherTunnelEnd(path.GetTile()) == par.GetTile()) {
            if (!AITunnel.BuildTunnel(AIVehicle.VT_ROAD, path.GetTile())) {
              /* An error occured while building a tunnel. TODO: handle it. */
            }
          } else {
            local bridge_list = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) + 1);
            bridge_list.Valuate(AIBridge.GetMaxSpeed);
            bridge_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
            if (!AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridge_list.Begin(), path.GetTile(), par.GetTile())) {
              /* An error occured while building a bridge. TODO: handle it. */
            }
          }
        }
      }
    }
    path = par;
  }
  AILog.Info("Done");
	
}
function CakiTTDAI::FindBestStationSpotForTown(town)
{
	AILog.Info("Building bus station to "+AITown.GetName(town));
	local center=AITown.GetLocation(town);
	if(!AIRoad.IsRoadTile(center))
		AILog.Info("Merkez yol değil...");
	local tl=AITileList();
	tl.AddRectangle(center-AIMap.GetTileIndex(15, 15),center+AIMap.GetTileIndex(15, 15));
	for(center=tl.Begin();tl.HasNext();center=tl.Next())
	{
		if(AIRoad.IsRoadTile(center) && AITile.IsWithinTownInfluence(center,town)/*&& AITile.IsBuildable(center)*/)
			tl.SetValue(center,1);
		else
			tl.SetValue(center,-1);
	}
	tl.RemoveValue(-1);
	local list = AICargoList();
	local passenger_cargo_id=null;
	for (local i = list.Begin(); list.HasNext(); i = list.Next()) {
		if (AICargo.HasCargoClass(i, AICargo.CC_PASSENGERS)) {
			passenger_cargo_id = i;
			break;
		}
	}
	local str=AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP);
	tl.Valuate(AITile.GetCargoAcceptance,passenger_cargo_id,1,1,str);
	tl.Sort(AIList.SORT_BY_VALUE,false);
	
	/*//Print cargo acceptences
	for(center=tl.Begin();tl.HasNext();center=tl.Next())
	{
		AILog.Info("Tile:"+center+" IsRoad:"+AIRoad.IsRoadTile(center)+" Value: "+tl.GetValue(center));
	}
	*/
	
	if(AITile.IsBuildable(center))
		AILog.Info("İnşa ok...");
	for(center=tl.Begin();tl.HasNext();center=tl.Next())
	{
		local front=center + AIMap.GetTileIndex(1, 0);
		if(!AIRoad.BuildDriveThroughRoadStation(center,front,AIRoad.ROADVEHTYPE_BUS,AIStation.STATION_NEW))
		{
			front=center + AIMap.GetTileIndex(0, 1);
			if(!AIRoad.BuildDriveThroughRoadStation(center,front,AIRoad.ROADVEHTYPE_BUS,AIStation.STATION_NEW))
			{
				front=center - AIMap.GetTileIndex(0, 1);
				if(!AIRoad.BuildDriveThroughRoadStation(center,front,AIRoad.ROADVEHTYPE_BUS,AIStation.STATION_NEW))
				{
					AILog.Info("İstasyon kurulamadı, başka kareye bakılıyor... "+AIError.GetLastErrorString());
					continue;
				}
			}
		}
		break;
	}
	
	//Build service depot
	tl.Sort(AIList.SORT_BY_VALUE,true);
	local tile=null;
	for(tile=tl.Begin();tl.HasNext();tile=tl.Next())
	{
		if(AIRoad.BuildRoadDepot(tile-AIMap.GetTileIndex(0,1),tile))
		{
			AIRoad.BuildRoad(tile,tile-AIMap.GetTileIndex(0,1));
			tile-=AIMap.GetTileIndex(0,1);
			break;
		}
		if(AIRoad.BuildRoadDepot(tile-AIMap.GetTileIndex(1,0),tile))
		{
			AIRoad.BuildRoad(tile,tile-AIMap.GetTileIndex(1,0));
			tile-=AIMap.GetTileIndex(1,0);
			break;
		}
		if(AIRoad.BuildRoadDepot(tile+AIMap.GetTileIndex(0,1),tile))
		{
			AIRoad.BuildRoad(tile,tile+AIMap.GetTileIndex(0,1));
			tile+=AIMap.GetTileIndex(0,1);
			break;
		}
		if(AIRoad.BuildRoadDepot(tile+AIMap.GetTileIndex(1,0),tile))
		{
			AIRoad.BuildRoad(tile,tile+AIMap.GetTileIndex(1,0));
			tile+=AIMap.GetTileIndex(1,0);
			break;
		}
			
	}
	
	AILog.Info("Done! building bus station to "+AITown.GetName(town));
	local t=[center,tile];
	return t;	
}

function CakiTTDAI::BuildRoute(ta,tb)
{
	local engine_list = AIEngineList(AIVehicle.VT_ROAD);
	local list = AICargoList();
	local passenger_cargo_id=null;
	for (local i = list.Begin(); list.HasNext(); i = list.Next()) {
		if (AICargo.HasCargoClass(i, AICargo.CC_PASSENGERS)) {
			passenger_cargo_id = i;
			break;
		}
	}
	engine_list.Valuate(AIEngine.GetCargoType);
	engine_list.KeepValue(passenger_cargo_id);
	
	local engine=engine_list.Begin();

	local str=AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP);
	
	AILog.Info("Mesafe:"+AIMap.DistanceManhattan(ta[0],tb[0])+ "Kargo Akseptans :) "+AITile.GetCargoAcceptance(ta[0],passenger_cargo_id,1,1,str)+", "+AITile.GetCargoAcceptance(tb[0],passenger_cargo_id,1,1,str));
	local VehicleCount=(AITile.GetCargoAcceptance(ta[0],passenger_cargo_id,1,1,str)>AITile.GetCargoAcceptance(tb[0],passenger_cargo_id,1,1,str)?AITile.GetCargoAcceptance(ta[0],passenger_cargo_id,1,1,str):AITile.GetCargoAcceptance(tb[0],passenger_cargo_id,1,1,str))*AIMap.DistanceManhattan(ta[0],tb[0])/600.0;
	
	for(local i=0;i<VehicleCount;i++)
	{
		local vehicle = AIVehicle.BuildVehicle(tb[1],engine);
		AIOrder.AppendOrder(vehicle, ta[0], AIOrder.OF_NONE);
		AIOrder.AppendOrder(vehicle, tb[0], AIOrder.OF_NONE);
		AIVehicle.StartStopVehicle(vehicle);
		Sleep(2);
	}
	
}

function CakiTTDAI::Start()
{
  AICompany.SetName("Caki'nin kampanisi ;)");
  /* Get a list of all towns on the map. */
  local townlist = AITownList();

  /* Sort the list by population, highest population first. */
  townlist.Valuate(AITown.GetPopulation);
  townlist.Sort(AIList.SORT_BY_VALUE, false);
  //Take the most populated city (ta)
  local ta=townlist.Begin();
  townlist.RemoveItem(ta);
  local taloc=AITown.GetLocation(ta);
  //Find the closest city to ta (tb)
  local tb=null;
  for(tb=townlist.Begin();townlist.HasNext();tb=townlist.Next())
  {
	townlist.SetValue(tb,AITown.GetPopulation(tb)/AIMap.DistanceManhattan(taloc,AITown.GetLocation(tb)));
  }
  townlist.Sort(AIList.SORT_BY_VALUE,false);
  tb=townlist.Begin();
  //AIRoad.AreRoadTilesConnected bakılacak...

  this.PrintFinancialStatus();
  /* Print the names of the towns we'll try to connect. */
  if(!AIRoad.AreRoadTilesConnected(AITown.GetLocation(ta),AITown.GetLocation(tb)))
  {
	this.ConnectTownsByRoad(ta,tb);
	AILog.Info("Going to connect " + AITown.GetName(ta) + " to " + AITown.GetName(tb));
  }
  else
	AILog.Info(AITown.GetName(ta) + " and " + AITown.GetName(tb) +" are already connected.No need to reconnect.");

  this.PrintFinancialStatus();

  local sa=this.FindBestStationSpotForTown(ta);
  this.PrintFinancialStatus();
  local sb=this.FindBestStationSpotForTown(tb);
  this.PrintFinancialStatus();
  this.BuildRoute(sa,sb);
  /*
  if(AIRoad.AreRoadTilesConnected(sa,sb))
	AILog.Info("Şehirler bağlı...");
  */
	while(true)
	{
		Sleep(500);
		//Repay the bank loan and get rid of the loan interests
		if(AICompany.GetBankBalance(AICompany.COMPANY_SELF)>0 && AICompany.GetLoanAmount()>0);
			AICompany.SetMinimumLoanAmount(AICompany.GetLoanAmount() - AICompany.GetBankBalance(AICompany.COMPANY_SELF));
		if( AICompany.GetBankBalance(AICompany.COMPANY_SELF) > AICompany.GetLoanAmount() )
			AICompany.SetMinimumLoanAmount(0);
		//AILog.Info("Bank: "+AICompany.GetBankBalance(AICompany.COMPANY_SELF)+" MaxLoan: "+AICompany.GetMaxLoanAmount()+" Loan: "+AICompany.GetLoanAmount());
		this.PrintFinancialStatus();
	}
}