#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include "EGN_Loader"

function NRB_Loaddir([update])
	variable update
	update = paramisdefault(update)? 0 : update
// this function loads the current directory, looking for all *primary.csv, listing all the * basenames
// along with the number of files
	svar /z pname = root:Packages:NikaNISTRSoXS:pathname
	if(!svar_Exists(pname))
		//print "no directory"
		return -1
	endif
	string filenames = sortlist(IndexedFile($pname, -1, ".csv"),";",4)
	String CurrentFolder=GetDataFolder(1)
	SetDataFolder root:Packages:NikaNISTRSoXS
	string /g oldcsvs
	if(stringmatch(oldcsvs,filenames))
		setdatafolder currentfolder
		NRB_loadprimary(update=1)
		return -2
	endif
	oldcsvs = filenames
	if(strlen(filenames)<1)
		make /o/n=(0,3) /t scanlist
		setdatafolder currentfolder
		//print "No txt files found in directory"
		return -3
	endif
	filenames = replacestring("-primary.csv",filenames,"")
	variable i
	
	
	
	for(i=itemsinlist(filenames)-1;i>=0;i-=1)
		if(stringmatch(stringfromlist(i,filenames),"*.csv"))
			filenames = removelistitem(i,filenames)
		endif
	endfor
	make /o/n=(itemsinlist(filenames),2) /t scanlist
	scanlist[][0]= stringfromlist(p,filenames)
	if(update==0)
		for(i=dimsize(scanlist,0)-1;i>=0;i-=1)
			LoadWave/Q/O/J/D/A/K=0/P=$(pname)/M /B="N=wave0;"  scanlist[i][0]+"-primary.csv"
			wave wavein = $stringfromlist(0,s_waveNames)
			scanlist[i][1] = num2str(dimsize(wavein,0)-1)
		endfor
	endif
	ListBox  ScansLB win=NISTRSoXSBrowser, selRow=(dimsize(scanlist,0)-1)
	//Controlupdate /W=NISTRSoXSBrowser ScansLB
	wave /z channellistsel
	channellistsel = 0
	NRB_loadprimary(row = dimsize(scanlist,0)-1)
	setdatafolder currentfolder
	return 1
	//listbox scansLB,selrow=-1
	
	
end

function NRB_loadprimary([update,row])
// when choosing a primary.csv file, populates a list of promary values, a scrollable list of baseline values
// and displays a list of datapoints with their primary motors defining the name
	variable update, row
	update = paramisdefault(update)? 0 : update
	variable /g scanrow
	if(paramisdefault(row))
		controlInfo scansLB
		scanrow = v_value
	else
		scanrow = row
	endif
	wave /t scanlist = root:Packages:NikaNISTRSoXS:scanlist
	
	if(scanrow<0 || scanrow >= dimsize(scanlist,0))
		return -1
	endif
	
	string basename = scanlist[scanrow][0]
	string basenum
	splitstring /e="^([[:digit:]]*)" basename, basenum
	svar /z pname = root:Packages:NikaNISTRSoXS:pathname
	if(!svar_Exists(pname))
		return -1
	endif
	svar pathtodata = root:Packages:NikaNISTRSoXS:pathtodata
		
	String CurrentFolder=GetDataFolder(1)
	SetDataFolder root:Packages:NikaNISTRSoXS
	string /g basescanname = basename
	string /g pnameimages = "NistRSoXS_Data"
	string /g pnamemd = "NistRSoXS_Metadata"
	newpath /o/q/z $pnameimages, pathtodata + basenum + ":"
	if(v_flag!=0)
		newpath /o/q $pnameimages, pathtodata
		pnamemd = pname
	else
		string listofjsonl = IndexedFile($pnameimages, -1, ".jsonl")
		if(strlen(listofjsonl)>0)
			pnamemd = pnameimages
		else
			pnamemd = pname
		endif
	endif

	killdatafolder /z channels
	newdatafolder /o/s channels
	//close /A

	newpath /o/q tempfolder, (getenvironmentVariable("TMP"))

	string tempfilename = "RSoXS"+num2str(round(abs(enoise(100000))))+".csv"
	getfilefolderinfo /q/z /p=tempfolder tempfilename
	copyfile /o/p=$(pname) basename+"-primary.csv" as getenvironmentVariable("TMP")+"\\"+ tempfilename
	LoadWave/q/O/J/D/A/K=0/P=tempfolder/W tempfilename
	deletefile /p=tempfolder tempfilename


	wave /z datawave = $(stringfromlist(0,S_waveNames))
	if(!waveexists(datawave))
		setdatafolder currentfolder
		return -1
	endif
	scanlist[scanrow][1] = num2str(dimsize(datawave,0))
	wave /t channellist = root:Packages:NikaNISTRSoXS:channellist
	wave channellistsel = root:Packages:NikaNISTRSoXS:channellistsel
	redimension /n=(itemsinlist(s_wavenames),2) channellist, channellistsel
	channellist[][1] = stringfromlist(p,s_wavenames)
	channellist[][0] = ""
	channellistsel[][0] = 32
	// pick out the channels to use for the sequence display
	wave /z en_energy, RSoXS_Sample_Outboard_Inboard, RSoXS_Sample_Up_Down
	wave /z seq_num
	wave /t steplist = root:Packages:NikaNISTRSoXS:steplist
	wave steplistsel = root:Packages:NikaNISTRSoXS:steplistsel
	variable oldnum = dimsize(steplist,0)
	steplist=""
	variable foundloc = 0
	if(whichlistitem("RSoXS_Sample_Outboard_Inboard",s_wavenames)>=0 && whichlistitem("RSoXS_Sample_Up_Down",s_wavenames)>=0)
		redimension /n=(dimsize(RSoXS_Sample_Up_Down,0)) steplist, steplistsel
		steplist[] = num2str(seq_num[p]) + " - (" + num2str(round(RSoXS_Sample_Outboard_Inboard[p]*100)/100) + " , " + num2str(round(RSoXS_Sample_Up_Down[p]*100)/100) + ")"
		foundloc = 1
	endif
	if(whichlistitem("timeW",s_wavenames)>=0)
		wave /z times = timeW
	else
		wave /z times
	endif
	if(whichlistitem("en_energy",s_wavenames)>=0)
		
		redimension /n=(dimsize(en_energy,0)) steplist, steplistsel
		steplist[] += num2str(seq_num[p]) + " - " + num2str(round(en_energy[p]*100)/100) + "eV"
	else 
	
		//not an energy scan, need to read something else .. what??
		
		//print "can't find energy"
		redimension /n=(dimsize(seq_num,0)) steplist, steplistsel
		steplist[] = "step " + num2str(seq_num[p])
	endif

	variable i
	if(dimsize(steplist,0)>oldnum && update)
		steplistsel = p>=oldnum ? 1 : steplistsel[p]
	endif	
	string matchingtiffs = IndexedFile($pnameimages, -1, ".tiff")
	
	string tifffilename
	
	variable stepswimages = 0
	for(i=0;i<(dimsize(seq_num,0));i+=1)
		tifffilename = stringfromlist(0,listMatch(matchingtiffs,basenum+"*primary*"+num2str(i)+".tiff"))
		if(strlen(tifffilename)<4)
			steplist[i] += " (no image)"
		else
			stepswimages += 1
		endif
	endfor
	if(stepswimages<1)
		redimension /n=(1) steplist, steplistsel
		steplist = "no images"
		steplistsel = 0x80
	else
		if(steplistsel[0] == 0x80)
			steplistsel = 0
		endif
	endif
	
	
	
	//monitors
	string mdfiles= indexedfile($(pnamemd),-1,".csv")
	string metadatafilenames = greplist(mdfiles,"^"+basename+".*_monitor[.]csv$")

	string mdfilename
	string monitorname
	duplicate /free times, goodpulse, rises, falls
	goodpulse = 0
	for(i=0;i<itemsinlist(metadatafilenames);i+=1)
		mdfilename = stringfromlist(i,metadatafilenames)
		Splitstring /e="^"+basename+"-(.*)_monitor[.]csv$" mdfilename, monitorname
		//print monitorname
		newpath /o/q tempfolder, (getenvironmentVariable("TMP"))
		tempfilename = "RSoXSmd"+num2str(round(abs(enoise(100000))))+".csv"
		getfilefolderinfo /q/z /p=tempfolder tempfilename
		copyfile /o/p=$(pnamemd) mdfilename as getenvironmentVariable("TMP")+"\\"+ tempfilename
		LoadWave/L={0,1,0,0,2}/Q/O/J/D/n=$cleanupname(monitorname,0)/K=0/P=tempfolder/m tempfilename
		deletefile /p=tempfolder tempfilename
	
		
		
		wave mdwave = $stringfromlist(0,s_wavenames)
		wave newchannelwave = NRB_splitsignal(mdwave,times, rises, falls, goodpulse)
		insertpoints /M=0 0,1, channellist, channellistsel
		channellist[0][1] = nameofwave(newchannelwave)
		channellist[0][0] = ""
		channellistsel[0][0] = 32
	endfor
	
	
	if(update)
		// we are essentially done now, we don't need to reload the metadata or baseline info, which hasn't changed
		setdatafolder currentfolder
		NRB_updateimageplot()
		return 1
	endif
	
	//populate the baseline and metadata lists
	
	wave /t mdlist = root:Packages:NikaNISTRSoXS:mdlist
	
	string jsonfiles= indexedfile($(pnamemd),-1,".jsonl")
	variable jsonfound=0
	string metadatafilename
	string metadata=""
	if(strlen(jsonfiles) < 5)
		//print "Currently can't load metadata json or jsonl file"
		mdlist = {"could not find metadata jsonl"}
	else
		jsonfound = 1
		metadatafilename = stringfromlist(0,greplist(jsonfiles,"^"+basename+".*jsonl"))
		metadata = addmetadatafromjson(pnamemd,"institution",metadatafilename,metadata)
		metadata = addmetadatafromjson(pnamemd,"project_name",metadatafilename,metadata)
		metadata = addmetadatafromjson(pnamemd,"proposal_id",metadatafilename,metadata)
		metadata = addmetadatafromjson(pnamemd,"sample_name",metadatafilename,metadata)
		metadata = addmetadatafromjson(pnamemd,"sample_desc",metadatafilename,metadata)
		metadata = addmetadatafromjson(pnamemd,"sample_id",metadatafilename,metadata)
		metadata = addmetadatafromjson(pnamemd,"sample_set",metadatafilename,metadata)
		metadata = addmetadatafromjson(pnamemd,"user_name",metadatafilename,metadata)
		metadata = addmetadatafromjson(pnamemd,"user_id",metadatafilename,metadata)
		metadata = addmetadatafromjson(pnamemd,"notes",metadatafilename,metadata)
		metadata = addmetadatafromjson(pnamemd,"uid",metadatafilename,metadata)
		metadata = addmetadatafromjson(pnamemd,"dim1",metadatafilename,metadata)
		metadata = addmetadatafromjson(pnamemd,"dim2",metadatafilename,metadata)
		metadata = addmetadatafromjson(pnamemd,"dim3",metadatafilename,metadata)
		metadata = addmetadatafromjson(pnamemd,"chemical_formula",metadatafilename,metadata)
		metadata = addmetadatafromjson(pnamemd,"density",metadatafilename,metadata)
		metadata = addmetadatafromjson(pnamemd,"project_desc",metadatafilename,metadata)
		metadata = replacestring(":",metadata,"  -  ")
		redimension /n=(itemsinlist(metadata)) mdlist
		mdlist[] = stringfromlist(p,metadata)
		
	endif	
	
	//baselines
	getfilefolderinfo /z /q /P=$(pnameimages) basename+"-baseline.csv"
	if(v_flag!=0)
		wave /z /t bllist = root:Packages:NikaNISTRSoXS:bllist
		bllist = {"no baselines found",""}
	else
		LoadWave/Q/O/J/D/n=baseline/K=0/P=$(pnameimages)/m  basename+"-baseline.csv"
		wave /t baselines = $stringfromlist(0,S_waveNames)
		matrixtranspose baselines
		duplicate /o baselines, root:Packages:NikaNISTRSoXS:bllist
	endif
	svar location = root:Packages:NikaNISTRSoXS:location
	if(waveexists(baselines))
		if(foundloc)
			findvalue /TEXT="en energy" baselines
			if(v_value>=0)
				location = baselines[v_value][1]
			else
				location = ""
			endif
		else
			findvalue /TEXT="RSoXS Sample Outboard-Inboard" baselines
			if(v_value>=0)
				location = "("+num2str(round(str2num(baselines[v_value][1])*100)/100) + ","
			else
				location = ""
			endif
			findvalue /TEXT="RSoXS Sample Up-Down" baselines
			if(v_value>=0)
				location += num2str(round(str2num(baselines[v_value][1])*100)/100) + ")"
			else
				location = ""
			endif
			
		endif
	endif
	
	
	
	
	
	
	NRB_updateimageplot()
	
	setdatafolder currentfolder
end


Function NRB_MetaBaseProc(tca) : TabControl
	STRUCT WMTabControlAction &tca

	switch( tca.eventCode )
		case 2: // mouse up
			Variable tab = tca.tab
			if(tab==0)
				ListBox MetadataLB,disable=0
				ListBox baselineLB,disable=1
			elseif(tab==1)
				ListBox MetadataLB,disable=1
				ListBox baselineLB,disable=0
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
Function NRB_datadispProc(tca) : TabControl
	STRUCT WMTabControlAction &tca

	switch( tca.eventCode )
		case 2: // mouse up
			Variable tab = tca.tab
			if(tab==0)
				setwindow NISTRSoXSBrowser#Graph2D,HIDE=1
				setwindow NISTRSoXSBrowser#Graph1D,HIDE=0
				SetVariable NRB_Mindisp,disable=1
				SetVariable NRB_Maxdisp,disable=1
				PopupMenu NRB_Colorpop,disable=1
				CheckBox NRB_logimg,disable=1
				Button NRB_Autoscale,disable=1
			elseif(tab==1)
				setwindow NISTRSoXSBrowser#Graph2D,HIDE=0
				setwindow NISTRSoXSBrowser#Graph1D,HIDE=1
				SetVariable NRB_Mindisp,disable=0
				SetVariable NRB_Maxdisp,disable=0
				PopupMenu NRB_Colorpop,disable=0
				CheckBox NRB_logimg,disable=0
				Button NRB_Autoscale,disable=0
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

function NRB_InitNISTRSoXS()
	dowindow /k NISTRSoXSBrowser
	NewPanel /W=(317,66,1673,931) /k=1 /N=NISTRSoXSBrowser as "NIST RSoXS data Browser"
	SetDrawLayer UserBack
	String CurrentFolder=GetDataFolder(1)
	setdatafolder root:
	newdatafolder /o/s Packages
	newdatafolder /o/s NikaNISTRSoXS		
	string /g pathtodata, colortab, location
	if(strlen(colortab)<3)
		colortab = "Terrain"
	endif
	variable /g minval = -500, maxval = 20000, logimage =0, leftmin=0, leftmax=1000, botmin=0, botmax=1000, darkview=0, saxsorwaxs=1
	
	
	
	variable /g bkgrunning = 1
	variable /g bkglastRunTicks = ticks
	variable /g bkgrunNumber = 0
	
	
	
	nvar /z scanrow
	if(!nvar_exists(scanrow))
		variable /g scanrow = -1
	endif
	wave /z/t scanlist, channellist, steplist, mdlist, bllist
	wave /z steplistsel, channellistsel
	if(!waveexists(scanlist))
		make /n=0/t scanlist
	endif
	if(!waveexists(steplist))
		make /n=0/t steplist
	endif
	if(!waveexists(channellist))
		make /n=0/t channellist
	endif
	if(!waveexists(channellistsel))
		make /n=0 channellistsel
	endif
	if(!waveexists(steplistsel))
		make /n=0 steplistsel
	endif
	if(!waveexists(mdlist))
		make /n=0/t mdlist
	endif
	if(!waveexists(bllist))
		make /n=0/t bllist
	endif
	make /o/n=2 /t scanlistboxcolumns = {"filenames","datapoints"}
	
	SetDataFolder $CurrentFolder
	
	ListBox ScansLB,pos={1.00,67.00},size={208.00,519.00},proc=NRB_ScanListBoxProc
	ListBox ScansLB,listWave=root:Packages:NikaNISTRSoXS:scanlist,row= 7,mode= 1
	ListBox ScansLB,selRow= 28,widths={124,60},userColumnResize= 1
	ListBox ChannelLB,pos={217.00,67.00},size={251.00,139.00}
	ListBox ChannelLB,listWave=root:Packages:NikaNISTRSoXS:channellist,widths={15,250}
	ListBox ChannelLB,selWave=root:Packages:NikaNISTRSoXS:channellistsel,mode= 4,proc=NRB_ChannelLBproc
	ListBox ScanStepLB,pos={217.00,272.00},size={251.00,377.00},proc=NRB_ScanStepLBproc
	ListBox ScanStepLB,listWave=root:Packages:NikaNISTRSoXS:steplist
	ListBox ScanStepLB,selWave=root:Packages:NikaNISTRSoXS:steplistsel,row=scanrow
	ListBox ScanStepLB,mode= 9
	GroupBox group0,pos={214.00,258.00},size={259.00,397.00},title="Scan Steps"
	GroupBox group1,pos={214.00,52.00},size={259.00,207.00},title="Channels (check X-axis)"
	GroupBox scangroupo,pos={0.00,52.00},size={213.00,538.00},title="Scans"
	TabControl metabase,pos={1.00,591.00},size={207.00,270.00},proc=NRB_MetaBaseProc
	TabControl metabase,tabLabel(0)="Metadata",tabLabel(1)="Baseline",value= 1
	ListBox MetadataLB,pos={4.00,617.00},size={198.00,239.00},disable=1
	ListBox MetadataLB,listWave=root:Packages:NikaNISTRSoXS:mdlist,row= 4,mode= 1
	ListBox MetadataLB,selRow=0
	ListBox baselineLB,pos={4.00,617.00},size={198.00,239.00}
	ListBox baselineLB,listWave=root:Packages:NikaNISTRSoXS:bllist
	ListBox baselineLB,widths={124,60,60},userColumnResize= 1
	Button Browsebut,pos={6.00,9.00},size={54.00,37.00},proc=NRB_Browsebutfunc,title="Browse"
	TitleBox Pathdisp,pos={64.00,11.00},size={400.00,20.00},fSize=10,frame=5
	TitleBox Pathdisp,variable= root:Packages:NikaNISTRSoXS:pathtodata,fixedSize=1
	TabControl datadisp,pos={474.00,4.00},size={875.00,860.00},proc=NRB_datadispProc
	TabControl datadisp,tabLabel(0)="1D data",tabLabel(1)="Images",value= 1
	Button LoadDarkBut,pos={216.00,720.00},size={125.00,34.00},proc=NRB_NIKADarkbut,title="Load as Dark(s)"
	Button OpenMaskBut,pos={216.00,682.00},size={125.00,34.00},proc=NRB_NIKAMaskbut,title="Open for Mask"
	Button BeamCenterBu,pos={344.00,682.00},size={125.00,34.00},proc=NRB_NIKABCbut,title="Open for\rBeam Geometry"
	Button ConvSelBut,pos={344.00,721.00},size={125.00,34.00},proc=NRB_NIKAbut,title="Convert Selection"
	Button QANTimportbut,pos={217.00,209.00},size={246.00,42.00},title="Import channels to\r QANT for analysis"
	GroupBox NIKAgroup,pos={214.00,662.00},size={259.00,98.00},title="NIKA Integration"
	Button NRB_SAXSWAXSbut,pos={235.00,767.00},size={206.00,39.00},proc=NRB_SWbutproc,title="SAXS images\r(click to toggle)"
	Button NRB_SAXSWAXSbut,labelBack=(65535,65535,65535),fStyle=1,fColor=(0,0,20000)
	Button NRB_SAXSWAXSbut,valueColor=(65535,65535,65535)
	SetVariable NRB_Mindisp,pos={620.00,5.00},size={80.00,18.00},bodyWidth=60,proc=NRB_ImageRangeChange,title="Min"
	SetVariable NRB_Mindisp,limits={-5000,500000,1},value=minval
	SetVariable NRB_Maxdisp,pos={720.00,5.00},size={80.00,18.00},bodyWidth=60,proc=NRB_ImageRangeChange,title="Max"
	SetVariable NRB_Maxdisp,limits={-5000,500000,1},value=maxval
	PopupMenu NRB_Colorpop,pos={802.00,6.00},size={200.00,19.00},proc=NRB_colorpopproc
	PopupMenu NRB_Colorpop,mode=8,value= #"\"*COLORTABLEPOPNONAMES*\""	
	CheckBox NRB_logimg,pos={1012.00,6.00},size={33.00,15.00},title="log",value=logimage,proc=NRB_logimagebutproc,variable=logimage
	Button NRB_Autoscale,pos={1069.00,6.00},size={68.00,15.00},proc=NRB_autoscalebut,title="Autoscale"
	CheckBox NRB_autocheck,pos={67.00,34.00},size={130.00,15.00},proc=NRB_autocheckproc,title="Refresh automatically"
	CheckBox NRB_autocheck,value= 0
	CheckBox NRB_Darkscheck,pos={292.00,816.00},size={73.00,15.00},proc=NRP_Viewdarks_butproc,title="View Darks"
	CheckBox NRB_Darkscheck,value= 1
	TitleBox Location,pos={1150.00,1.00},size={254.00,23.00}
	TitleBox Location,variable= root:Packages:NikaNISTRSoXS:location
	
	Display/W=(481,28,1344,860)/HOST=# /HIDE=1 
	RenameWindow #,Graph1D
	SetActiveSubwindow ##
	Display/W=(481,28,1344,860)/HOST=# 
	RenameWindow #,Graph2D
	SetActiveSubwindow ##
	
	
	
	
End

Function NRB_autocheckproc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			if(checked)
				CtrlNamedBackground NRB_BG, burst=0, proc=NRB_BGTask, period=	10, dialogsOK=1, kill=0, start
			else
				CtrlNamedBackground NRB_BG, stop, kill=1
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function NRB_Browsebutfunc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	switch( ba.eventCode )
		case 2: // mouse up
			NRB_browse()
			if(NRB_Loaddir()>=0)
				NRB_loadprimary()
			endif
			break
	endswitch
	return 0
End

function NRB_browse()
	String CurrentFolder=GetDataFolder(1)
	SetDataFolder root:Packages:NikaNISTRSoXS
	svar pathtodata
	pathinfo Path_NISTRSoXS
	NewPath/q/z/O/m="path for txt files" Path_NISTRSoXS		// This will put up a dialog
	if (V_flag == 0)
		string /g pathname
		pathname = "Path_NISTRSoXS"
		PathInfo Path_NISTRSoXS
		pathtodata = s_path
	endif
	SetDataFolder $CurrentFolder
end


Function NRB_ScanListBoxProc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba
	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave
	switch( lba.eventCode )
		case 4: // cell selection
		case 5: // cell selection plus shift key
			NRB_loadprimary()
			break
		case 3:
			NRB_Loaddir()
			break
	endswitch
	return 0
End



Function NRB_SWbutproc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			string currentdatafolder = getdatafolder(1)
			setdatafolder root:Packages:NIKANISTRSoXS
			variable /g saxsorwaxs 
			saxsorwaxs = abs(saxsorwaxs-1)
			if(saxsorwaxs)
				button NRB_SAXSWAXSbut fColor=(0,0,20000),title="SAXS images\r(click to toggle)",valueColor=(65535,65535,65535)
			else
				button NRB_SAXSWAXSbut fColor=(1,26214,0),title="WAXS images\r(click to toggle)",valueColor=(0,0,0)
			endif
			NRB_updateimageplot()
			setdatafolder currentdatafolder
		case -1: // control being killed
			break
	endswitch

	return 0
End

function NRB_updateimageplot([autoscale])
	variable autoscale
	autoscale = paramisDefault(autoscale)? 0 : autoscale
	wave selwave = root:Packages:NikaNISTRSoXS:steplistsel
	variable i, num 
	duplicate /free selwave, tempwave
	tempwave = selwave[p]? 1 : 0
	num = sum(tempwave)
	NRB_MakeImagePlots(num)
	string listofsteps = ""
	for(i=0;i<dimsize(selwave,0);i+=1)
		if(selwave[i])
			listofsteps = addlistitem(num2str(i),listofsteps)
		endif
	endfor
	NRB_loadimages(listofsteps, autoscale=autoscale)
end

function NRB_MakeImagePlots(num)
	variable num
	variable numx, numy
	//481,28,1344,860
	//863,832
	string currentfolder = getdatafolder(1)
	setdatafolder root:Packages:NIKANISTRSoXS
	wave /z/t imagenames
	variable i
	if(waveexists(imagenames))
		for(i=0;i<dimsize(imagenames,0);i+=1)
			killwindow /z NISTRSoXSBrowser#Graph2D#$imagenames[i]
		endfor
	endif
	make /o/n=(num) /t imagenames
	
	
	numy = floor(.5+sqrt(num-.75))
	numx = ceil(num/numy)
	
	variable sizex, sizey
	sizex = floor(863 / numx)
	sizey = floor(832 / numy)
	
	variable xloc=0, yloc=0
	variable imnum = 0
	imagenames = "NRB_image"+num2str(p)
	for(yloc=0;yloc<numy;yloc+=1)
		for(xloc=0;xloc<numx;xloc+=1)
			Display/W=(sizex*xloc,sizey*yloc,sizex*(xloc+1),sizey*(yloc+1))/HOST=NISTRSoXSBrowser#Graph2D /n=$imagenames[imnum]
			imnum+=1
			if(imnum>=num)
				break
			endif
		endfor
		if(imnum>=num)
			break
		endif
	endfor
	
	
end

Function NRB_ScanStepLBproc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave

	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			break
		case 3: // double click
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
			NRB_updateimageplot()
			//NRB_updateimageplot(autoscale=1)
			break
		case 6: // begin edit
			break
		case 7: // finish edit
			break
		case 12: // keystroke
			NRB_Loaddir()
			break
		case 13: // checkbox clicked (Igor 6.2 or later)
			break
	endswitch

	return 0
End

function NRB_loadimages(listofsteps,[autoscale])
	string listofsteps
	variable autoscale
	autoscale = paramisDefault(autoscale)? 0 : autoscale
	listofsteps = sortlist(listofsteps,";",2)
	string currentfolder =getdatafolder(1)
	setdatafolder root:Packages:NIKANISTRSoXS
	svar basescanname
	svar /z colortab
	nvar /z saxsorwaxs
	nvar /z darkview
	nvar /z leftmin
	nvar /z leftmax
	nvar /z botmin
	nvar /z botmax
	nvar /z logimage
	svar /z pname = root:Packages:NikaNISTRSoXS:pnameimages
	wave /t imagenames
	wave /t steplist
	killdatafolder /z images
	newdatafolder /o/s images
	string tiffnames = IndexedFile($pname, -1, ".tiff")
	string matchingtiffs = listMatch(tiffnames,basescanname+"*")
	string tifffilename
	
	nvar /z minval = root:Packages:NikaNISTRSoXS:minval
	nvar /z maxval = root:Packages:NikaNISTRSoXS:maxval
	
	variable minv, maxv, totmaxv = -5000, totminv = 5e10
	variable i
	make /free /n=(itemsinlist(listofsteps)) success=0
	
	string primeordark
	if(darkview)
		primeordark = "*dark-Synced_"
	else
		primeordark = "*primary-Synced_"
	endif
	for(i=0;i<itemsinlist(listofsteps);i+=1)

		if(saxsorwaxs)
			tifffilename = stringfromlist(0,listMatch(matchingtiffs,primeordark + "saxs*-"+stringfromlist(i,listofsteps)+".tiff"))
		else
			tifffilename = stringfromlist(0,listMatch(matchingtiffs,primeordark + "waxs*-"+stringfromlist(i,listofsteps)+".tiff"))
		endif
		if(strlen(tifffilename)<4)
			success[i] = 0 
			//print "Could not find image to display"
			
		else
			ImageLoad/q/P=$(pname)/T=tiff/O/N=$("image"+num2str(i)) tifffilename
			wave image = $("image"+num2str(i))
			redimension /i image
			histogram /B=3 image
			imageinterpolate /dest=$("imagesm"+num2str(i)) /pxsz={floor(sqrt(itemsinlist(listofsteps))),floor(sqrt(itemsinlist(listofsteps)))} pixelate image
			wave imagesm = $("imagesm"+num2str(i))
			killwaves /z image
			appendimage /w=NISTRSoXSBrowser#Graph2D#$imagenames[i] imagesm
			ModifyGraph /w=NISTRSoXSBrowser#Graph2D#$imagenames[i] margin=1,nticks=0,standoff=0
			ModifyImage /w=NISTRSoXSBrowser#Graph2D#$imagenames[i] ''#0 log=logimage,ctab= {minval,maxval,$colortab,0}
			TextBox /w=NISTRSoXSBrowser#Graph2D#$imagenames[i]/S=0/F=0 steplist[str2num(stringfromlist(i,listofsteps))]
			minv = wavemin(imagesm)
			maxv = wavemax(imagesm)
			if(minv<totminv)
				totminv = minv
			endif
			if(maxv>totmaxv)
				totmaxv = maxv
			endif
			success[i] = 1
		endif
	endfor
	if(autoscale)
		setaxis /A /w=NISTRSoXSBrowser#Graph2D#$imagenames[0]
		doupdate
		getaxis /q/w=NISTRSoXSBrowser#Graph2D#$imagenames[0] left
		leftmin = v_min
		leftmax = v_max
		getaxis /q/w=NISTRSoXSBrowser#Graph2D#$imagenames[0] bottom
		botmin = v_min
		botmax = v_max
		minval = totminv
		maxval = totmaxv
	else
	//	if(totminv > minval)
	//		minval = totminv
	//	endif
	//	if(totmaxv < maxval)
	//		maxval = totmaxv
	//	endif
	endif
	for(i=0;i<itemsinlist(listofsteps);i+=1)
		if(success[i])
			variable realminval = logimage? max(1,minval) : minval
			ModifyImage /w=NISTRSoXSBrowser#Graph2D#$imagenames[i] ''#0 log=logimage,ctab= {realminval,maxval,$colortab,0}
		endif
	endfor
	
	
	
	setdatafolder currentfolder
end

Function NRB_ImageRangeChange(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			NRB_updateimages()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function NRB_colorpopproc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			svar /z colortab = root:Packages:NikaNISTRSoXS:colortab
			if(svar_exists(colortab))
				colortab = popStr
				NRB_updateimages()
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

function NRB_updateimages()
	svar /z colortab = root:Packages:NikaNISTRSoXS:colortab
	nvar /z minval = root:Packages:NikaNISTRSoXS:minval
	nvar /z maxval = root:Packages:NikaNISTRSoXS:maxval
	nvar /z logimage = root:Packages:NikaNISTRSoXS:logimage
	nvar /z leftmin = root:Packages:NikaNISTRSoXS:leftmin
	nvar /z leftmax = root:Packages:NikaNISTRSoXS:leftmax
	nvar /z botmin = root:Packages:NikaNISTRSoXS:botmin
	nvar /z botmax = root:Packages:NikaNISTRSoXS:botmax
	wave /z/t imagenames  = root:Packages:NikaNISTRSoXS:imagenames
	setwindow NISTRSoXSBrowser,hook(syncaxes)=$"" 
	if(waveexists(imagenames) && svar_exists(colortab) && nvar_exists(minval) && nvar_exists(maxval) && nvar_exists(logimage))
		variable i
		for(i=0;i<dimsize(imagenames,0);i+=1)
			
			ModifyImage /w=NISTRSoXSBrowser#Graph2D#$imagenames[i] ''#0 log=(logimage),ctab= {minval,maxval,$colortab,0}
			setaxis /w=NISTRSoXSBrowser#Graph2D#$imagenames[i] left, leftmin, leftmax
			setaxis /w=NISTRSoXSBrowser#Graph2D#$imagenames[i] bottom, botmin, botmax
			
		endfor
	endif
	setwindow NISTRSoXSBrowser,hook(syncaxes)=NRB_axishook
end
	

Function NRB_logimagebutproc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			NRB_updateimageplot()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function NRB_axishook(s)
	STRUCT WMWinHookStruct &s
	Variable hookResult = 0
	//print s.eventCode
	switch(s.eventCode)
		case 4:
			break
		case 11:
			GetWindow $s.winName activeSW
			if(!stringmatch(s_value,"*NRB_image*"))
				break
			endif
		case 6:
		case 8: // modified
			nvar /z leftmin = root:Packages:NikaNISTRSoXS:leftmin
			nvar /z leftmax = root:Packages:NikaNISTRSoXS:leftmax
			nvar /z botmin = root:Packages:NikaNISTRSoXS:botmin
			nvar /z botmax = root:Packages:NikaNISTRSoXS:botmax
			GetWindow $s.winName activeSW
			string subwindow = s_value
			print subwindow
			getaxis /w=$(subwindow) left ;variable err = GetRTError(1)
			if(err)
				break
			endif
			leftmin = v_min
			leftmax = v_max
			getaxis /w=$(subwindow) bottom
			botmin = v_min
			botmax = v_max
			NRB_updateimages()
			hookresult = 1
			break
		case 2:
			NVAR running= root:Packages:NikaNISTRSoXS:bkgrunning
			running = 0
			CtrlNamedBackground NRB_BG, stop
			break
		default:
			//print s.eventcode	
	endswitch
	return hookResult // 0 if nothing done, else 1
End

Function NRB_autoscalebut(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			NRB_updateimageplot(autoscale=1)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End



Function NRB_ChannelLBproc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave

	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			break
		case 3: // double click
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
			NRB_plotchannels()
			break
		case 6: // begin edit
			break
		case 7: // finish edit
			break
		case 13: // checkbox clicked (Igor 6.2 or later)
			string x_axis
			if(selwave[row] & 16)
				//checkbox on
				x_axis = listwave[row][1]
				variable i
				for(i=0;i<dimsize(selwave,0);i+=1)
					if(i!=row && selwave[i] & 16)
						selwave[i] -=16
					endif
				endfor
			else
				for(i=0;i<dimsize(selwave,0);i+=1)
					if(i!=0 && selwave[i] & 16)
						selwave[i] -=16
					endif
					if(!(selwave[0] & 16))
						selwave[0] += 16
					endif
				endfor
				x_axis = listwave[0][1]
			endif
			string currenfolder = getdatafolder(1)
			setdatafolder root:Packages:NikaNISTRSoXS:
			string /g x_axisname = x_axis
			NRB_plotchannels(fresh=1)
			break
	endswitch

	return 0
End


function NRB_plotchannels([fresh])
	variable fresh
	fresh = paramisdefault(fresh)? 0 : fresh
	wave /t listwave = root:Packages:NikaNISTRSoXS:channellist
	wave selwave = root:Packages:NikaNISTRSoXS:channellistsel
	
	make /free /n=(dimsize(selwave,0)) selected
	selected = selwave[p] & 1
	variable num = sum(selected)
	string channels2plot = ""
	variable j
	for(j=0;j<dimsize(selwave,0);j+=1)
		if(selected[j])
			channels2plot = addlistitem(listwave[j][1],channels2plot)
		endif
	endfor
	
	string plottedchannels = tracenamelist("NISTRSoXSBrowser#Graph1D",";",1)
	string channeltoplot
	string plottedchannel
	svar /z x_axisname = root:Packages:NikaNISTRSoXS:x_axisname
	if(!svar_exists(x_axisname))
		print "Cannot plot anything until an X-axis is chosen"
		return 0
	endif
	
	variable i
	for(i=itemsinlist(plottedchannels)-1;i>=0;i-=1)
		plottedchannel = stringfromlist(i,plottedchannels)
		if(fresh || (whichlistitem(plottedchannel,channels2plot)<0))
			removefromgraph /z /w=NISTRSoXSBrowser#Graph1D $plottedchannel
		endif
	endfor
	
	plottedchannels = tracenamelist("NISTRSoXSBrowser#Graph1D",";",1)
	
	
	wave xwave = root:Packages:NikaNISTRSoXS:channels:$x_axisname
	for(i=0;i<itemsinlist(channels2plot);i+=1)
		channeltoplot = stringfromlist(i,channels2plot)
		if(stringmatch(channeltoplot,x_axisname) || whichlistitem(channeltoplot,plottedchannels)>=0)
			continue
		endif
		wave channel = root:Packages:NikaNISTRSoXS:channels:$channeltoplot
		wave /z errorwave = root:Packages:NikaNISTRSoXS:channels:$replacestring("m_",channeltoplot,"s_")
		appendtograph /w=NISTRSoXSBrowser#Graph1D channel vs xwave
		if(waveexists(errorwave) && stringmatch(channeltoplot,"m_*"))
			ErrorBars /w=NISTRSoXSBrowser#Graph1D $nameofwave(channel) SHADE= {0,0,(0,0,0,0),(0,0,0,0)},wave=(errorwave,errorwave)
		endif
	endfor
	NRB_ColorTraces("SpectrumBlack","NISTRSoXSBrowser#Graph1D")
end

function NRB_ColorTraces(Colortabname,Graphname)
	string colortabname, graphname
	
	if(cmpstr(graphName,"")==0)
		graphname = WinName(0, 1)
	endif
	if (strlen(graphName) == 0)
		return -1
	endif

	Variable numTraces =itemsinlist(TraceNameList(graphName,";",1))
	if (numTraces <= 0)
		return -1
	endif
	variable numtracesden=numtraces
	if( numTraces < 2 )
		numTracesden= 2	// avoid divide by zero, use just the first color for 1 trace
	endif

	ColorTab2Wave $colortabname
	wave RGB = M_colors
	Variable numRows= DimSize(rgb,0)
	Variable red, green, blue
	Variable i, index
	for(i=0; i<numTraces; i+=1)
		index = round(i/(numTracesden-1) * (numRows*2/3-1))	// spread entire color range over all traces.
		ModifyGraph/w=$graphName rgb[i]=(rgb[index][0], rgb[index][1], rgb[index][2])
	endfor
end




function NRB_convertpathtonika([main,mask,dark,beamcenter])
	variable mask,dark,beamcenter,main
	svar /z pname = root:Packages:NikaNISTRSoXS:pnameimages
	PathInfo $pname
	if(main)
		EGNA_Convert2Dto1DMainPanel()
		svar SampleNameMatchStr = root:Packages:Convert2Dto1D:SampleNameMatchStr
		SampleNameMatchStr = ""
		popupmenu Select2DDataType win=EGNA_Convert2Dto1DPanel, popmatch="BS_Suitcase_Tiff"
		newpath /O/Q/Z Convert2Dto1DDataPath S_path
		SVAR MainPathInfoStr=root:Packages:Convert2Dto1D:MainPathInfoStr
		MainPathInfoStr=S_path
		TitleBox PathInfoStrt, win =EGNA_Convert2Dto1DPanel, variable=MainPathInfoStr
		EGNA_UpdateDataListBox()	
	endif
	if(mask)
		NI1M_CreateMask()
		newpath /O/Q/Z Convert2Dto1DMaskPath S_path
		popupmenu CCDFileExtension win=NI1M_ImageROIPanel, popmatch="BS_Suitcase_Tiff"
		SVAR CCDFileExtension=root:Packages:Convert2Dto1D:CCDFileExtension
		CCDFileExtension = "BS_Suitcase_Tiff"
		NI1M_UpdateMaskListBox()
	endif
	if(dark)
		EGNA_Convert2Dto1DMainPanel()
		newpath /O/Q/Z Convert2Dto1DEmptyDarkPath S_path
		popupmenu SelectBlank2DDataType win=EGNA_Convert2Dto1DPanel, popmatch="BS_Suitcase_Tiff"
		nVAR usedarkfield=root:Packages:Convert2Dto1D:UseDarkField
		usedarkfield=1
		SVAR BlankFileExtension=root:Packages:Convert2Dto1D:BlankFileExtension
		BlankFileExtension = "BS_Suitcase_Tiff"
		SVAR DataFileExtension=root:Packages:Convert2Dto1D:DataFileExtension
		DataFileExtension = "BS_Suitcase_Tiff"
		svar EmptyDarkNameMatchStr = root:Packages:Convert2Dto1D:EmptyDarkNameMatchStr
		EmptyDarkNameMatchStr = ""
		EGNA_UpdateEmptyDarkListBox()	
	endif
	if(beamcenter)
		EGN_CreateBmCntrFile()
		newpath /O/Q/Z Convert2Dto1DBmCntrPath S_path
		popupmenu BmCntrFileType win=EGN_CreateBmCntrFieldPanel, popmatch="BS_Suitcase_Tiff"
		SVAR BmCntrFileType=root:Packages:Convert2Dto1D:BmCntrFileType
		BmCntrFileType = "BS_Suitcase_Tiff"
		SVAR BCPathInfoStr=root:Packages:Convert2Dto1D:BCPathInfoStr
		BCPathInfoStr=S_Path
		NI1BC_UpdateBmCntrListBox()
	endif
end


function /t NRB_getfilenames()
	string currentfolder =getdatafolder(1)
	setdatafolder root:Packages:NIKANISTRSoXS
	wave selwave = root:Packages:NikaNISTRSoXS:steplistsel
	variable i
	string listofsteps = ""
	for(i=0;i<dimsize(selwave,0);i+=1)
		if(selwave[i])
			listofsteps = addlistitem(num2str(i),listofsteps)
		endif
	endfor

	svar basescanname
	nvar saxsorwaxs, darkview
	svar /z pname = root:Packages:NikaNISTRSoXS:pnameimages
	wave /t steplist
	killdatafolder /z images
	newdatafolder /o/s images
	string tiffnames = IndexedFile($pname, -1, ".tiff")
	string matchingtiffs = listMatch(tiffnames,basescanname+"*")
	string filenames = ""
	string tifffilename = ""
	
	string primeordark
	if(darkview)
		primeordark = "*dark-Synced_"
	else
		primeordark = "*primary-Synced_"
	endif
	for(i=0;i<itemsinlist(listofsteps);i+=1)
		if(saxsorwaxs)
			tifffilename = stringfromlist(0,listMatch(tiffnames,basescanname + primeordark +"saxs*-"+stringfromlist(i,listofsteps)+".tiff"))
		else
			tifffilename = stringfromlist(0,listMatch(tiffnames,basescanname + primeordark +"waxs*-"+stringfromlist(i,listofsteps)+".tiff"))
		endif
		filenames = addlistitem(tifffilename,filenames)
	endfor
	return filenames
	
end

Function NRB_NIKABCbut(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up			
			string filelist = NRB_getfilenames()
			NRB_loadforbeamcenteringinNIKA(stringfromlist(0,filelist))
			break
	endswitch
	return 0
End
Function NRB_NIKADarkbut(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string filelist = NRB_getfilenames()
			NRB_loadasdarkinnika(filelist)
			break
	endswitch
	return 0
End
Function NRB_NIKAMaskbut(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string filelist = NRB_getfilenames()
			NRB_loadformaskinnika(stringfromlist(0,filelist))
			break
	endswitch

	return 0
End

Function NRB_NIKAbut(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string filelist = NRB_getfilenames()
			NRB_convertnikafilelistsel(filelist)
			break
	endswitch

	return 0
End


function NRB_loadasdarkinnika(filenamelist)
	string filenamelist
	string filename
	NRB_convertpathtonika(dark=1)
	doupdate
	Wave/T  ListOffilenames=root:Packages:Convert2Dto1D:ListOf2DEmptyData
	variable i=0
	for(i=0;i<itemsinlist(filenamelist);i+=1)
		filename = stringfromlist(i,filenamelist)
		FindValue /TEXT=filename /TXOP=6 /Z ListOffilenames
		if(v_value>=0)
			listbox Select2DMaskDarkWave win=EGNA_Convert2Dto1DPanel, selrow=v_value 
			doupdate
			EGNA_LoadEmptyOrDark("Dark")
		endif
	endfor
end

function NRB_loadformaskinnika(filename)
	string filename
	NRB_convertpathtonika(mask=1)
	doupdate
	Wave/T  ListOffilenames=root:Packages:Convert2Dto1D:ListOfCCDDataInCCDPath
	variable i
	FindValue /TEXT=filename /TXOP=6 /Z ListOffilenames
	if(v_value>=0)
		listbox CCDDataSelection win=NI1M_ImageROIPanel, selrow=v_value 
		doupdate
		NI1M_MaskCreateImage() 
	endif
end

function NRB_loadforbeamcenteringinNIKA(filename)
	string filename
	NRB_convertpathtonika(beamcenter=1)
	doupdate
	Wave/T  ListOffilenames=root:Packages:Convert2Dto1D:ListOfCCDDataInBmCntrPath
	FindValue /TEXT=filename /TXOP=6 /Z ListOffilenames
	if(v_value>=0)
		listbox CCDDataSelection win=EGN_CreateBmCntrFieldPanel, selrow=v_value 
		doupdate
		NI1BC_BmCntrCreateImage()
		NVAR BMMaxCircleRadius=root:Packages:Convert2Dto1D:BMMaxCircleRadius
		Wave BmCntrFieldImg=root:Packages:Convert2Dto1D:BmCntrCCDImg 
		BMMaxCircleRadius=sqrt(DimSize(BmCntrFieldImg, 0 )^2 + DimSize(BmCntrFieldImg, 1 )^2)
		Slider BMHelpCircleRadius,limits={1,BMMaxCircleRadius,0}, win=EGN_CreateBmCntrFieldPanel
		SetVariable BMHelpCircleRadiusV,limits={1,BMMaxCircleRadius,0}, win=EGN_CreateBmCntrFieldPanel
		NVAR BMImageRangeMinLimit= root:Packages:Convert2Dto1D:BMImageRangeMinLimit
		NVAR BMImageRangeMaxLimit = root:Packages:Convert2Dto1D:BMImageRangeMaxLimit
		Slider ImageRangeMin,limits={BMImageRangeMinLimit,BMImageRangeMaxLimit,0}, win=EGN_CreateBmCntrFieldPanel
		Slider ImageRangeMax,limits={BMImageRangeMinLimit,BMImageRangeMaxLimit,0}, win=EGN_CreateBmCntrFieldPanel
		NI1BC_DisplayHelpCircle()
		NI1BC_DisplayMask()
		TabControl BmCntrTab, value=0, win=EGN_CreateBmCntrFieldPanel
		showinfo /w=CCDImageForBmCntr
	endif
end

function NRB_convertnikafilelistsel(filenamelist)
	string filenamelist
	NRB_convertpathtonika(main=1)
	doupdate
	Wave/T  ListOf2DSampleData=root:Packages:Convert2Dto1D:ListOf2DSampleData
	Wave ListOf2DSampleDataNumbers=root:Packages:Convert2Dto1D:ListOf2DSampleDataNumbers
	ListOf2DSampleDataNumbers = 0
	string filename = stringfromlist(0,filenamelist)
	variable i
	for(i=0;i<itemsinlist(filenamelist);i+=1)
		filename = stringfromlist(i,filenamelist)
		FindValue /TEXT=filename /TXOP=6 /Z ListOf2DSampleData
		if(v_value>=0)
			ListOf2DSampleDataNumbers[v_value] = 1
		endif
	endfor
	doupdate
	EGNA_CheckParametersForConv()
	//set selections for using RAW/Converted data...
	NVAR LineProfileUseRAW=root:Packages:Convert2Dto1D:LineProfileUseRAW
	NVAR LineProfileUseCorrData=root:Packages:Convert2Dto1D:LineProfileUseCorrData
	NVAR SectorsUseRAWData=root:Packages:Convert2Dto1D:SectorsUseRAWData
	NVAR SectorsUseCorrData=root:Packages:Convert2Dto1D:SectorsUseCorrData
	LineProfileUseRAW=0
	LineProfileUseCorrData=1
	SectorsUseRAWData=0
	SectorsUseCorrData=1
	//selection done
	EGNA_LoadManyDataSetsForConv()
end

Function NRB_BGTask(s)
	STRUCT WMBackgroundStruct &s
	NVAR running= root:Packages:NikaNISTRSoXS:bkgrunning
	if( running == 0 )
		return 0 // not running -- wait for user
	endif
	NVAR lastRunTicks= root:Packages:NikaNISTRSoXS:bkglastRunTicks
	if( (lastRunTicks+60) >= ticks )
		return 0 // not time yet, wait
	endif
	NVAR runNumber= root:Packages:NikaNISTRSoXS:bkgrunNumber
	runNumber += 1
	NRB_Loaddir()
	
	doupdate
	lastRunTicks= ticks
	return 0
End

Function NRP_Viewdarks_butproc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			
			string currentdatafolder = getdatafolder(1)
			setdatafolder root:Packages:NIKANISTRSoXS
			variable /g darkview 
			darkview = checked
			NRB_updateimageplot()
			setdatafolder currentdatafolder
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

function /wave NRB_splitsignal(wavein,times, rises, falls, goodpulse)
	wave wavein,times, rises, falls,goodpulse
	
	make /free /n=(dimsize(wavein,0)) /d timesin = wavein[p][0], datain = wavein[p][1]
	
	string name = nameofwave(wavein)
	wave /z waveout = $("_"+name)
	if(numpnts(wavein)<2* numpnts(times))
		print "not valid waves"
		return waveout
	endif
	make /o/n=(dimsize(times,0)) $("m_"+name), $("s_"+name), $("f_"+name)
	wave waveout = $("m_"+name), stdwave = $("s_"+name), fncwave = $("f_"+name)
	make /n=(dimsize(times,0)) /free pntlower, pntupper
	pntupper = binarysearch(timesin,times[p])
	pntupper = pntupper[p]==-2 ? numpnts(timesin)-1 : pntupper[p]
	duplicate /o /free pntupper, pntlower, pntlower1
	pntlower1 = binarysearch(timesin,times[p]-1.5)
	
	insertpoints /v=0 0,1,pntlower
	make /free temprises, tempfalls
	waveout = mean(datain,pntlower1[p]+2,pntupper[p]-0)
	stdwave = sqrt(variance(datain,pntlower1[p]+2,pntupper[p]-0))
	variable i, meanvalue, alreadygood, err
	for(i=0;i<dimsize(times,0);i+=1)
		//meanvalue = mean(datain,pntlower[i],pntupper[i])
		meanvalue = (9/10) *(wavemin(datain,pntlower[i],pntupper[i]) + wavemax(datain,pntlower[i],pntupper[i]))
		try
			findlevels /B=3/EDGE=1 /Q /P /D=temprises /R=[max(0,pntlower[i]),min(numpnts(datain)-1,pntupper[i])] datain, meanvalue;AbortonRTE // look for rising and falling edges
			findlevels /B=3/EDGE=2 /Q /P /D=tempfalls /R=[max(0,pntlower[i]),min(numpnts(datain)-1,pntupper[i])] datain, meanvalue;AbortonRTE
		catch
			err = getRTError(1)
			//print getErrMessage(err)
			goodpulse[i]=0
			break
		endtry
		if(dimsize(temprises,0) == 1 && dimsize(tempfalls,0)== 1 ) // did we find a single pulse?
			alreadygood = goodpulse[i]
			rises[i] = timesin(temprises[0]) // if so, change them to times (so they work for all channels)
			falls[i] = timesin(tempfalls[0])
			waveout[i] = mean(datain,binarysearchinterp(timesin,rises[i])+1,binarysearchinterp(timesin,falls[i])-1)
			stdwave[i] = sqrt(variance(datain,binarysearchinterp(timesin,rises[i])+1,binarysearchinterp(timesin,falls[i])-1))
			goodpulse[i]=1
		else
			if(alreadygood) // have we already found the rising and falling times?
				waveout[i] = mean(datain,binarysearch(timesin,rises[i])+0,binarysearch(timesin,falls[i]))
				stdwave[i] = sqrt(variance(datain,binarysearch(timesin,rises[i])+0,binarysearch(timesin,falls[i])))
			else
				goodpulse[i]=0
			endif
		endif
	endfor
	
	//curvefit
	return waveout
end