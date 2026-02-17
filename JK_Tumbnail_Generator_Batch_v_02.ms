/* Batch Thumbnail Creator for 3ds Max 2022
   Batch Thumbnail Creator
    Version: 1.2
    
    Idea & Creation by: Bate July and some AI tools
    
    LICENSE: OPEN SOURCE / FREE TO USE
    -------------------------------------------------------------------------
    This script is free to use for both personal and commercial projects. 
    You are welcome to modify, edit, or extend the code to fit your needs.
    
    If you distribute a modified version or find this useful, a mention 
    of the original creator (Bate July and some AI tools) is greatly appreciated!
    
    Keep it open, keep it free, and happy rendering.
*/

try(destroyDialog outputRollout)catch()

rollout outputRollout "Batch Thumbnail Creator v1.2" width:300 height:600
(
    -- // UI LAYOUT //
    
    group "1. Output Configuration"
    (
        button btn_browse "Select Output Folder..." width:260 height:30 align:#center
        edittext et_path "" readOnly:true width:260 align:#center
    )

    group "2. Camera & Settings"
    (
        label lbl_cam "Select Camera:" align:#left
        dropdownlist ddl_cameras "" width:200 align:#left across:2
        button btn_refresh "?" width:50 align:#right toolTip:"Refresh Camera List"
        
        checkbox chk_useRenderSettings "Use Current Render Settings" checked:true align:#left
        label lbl_hint "If unchecked: Forces 512x512 .jpg" style_sunken:false enabled:false
    )

    group "3. Scene Context (Backgrounds)"
    (
        checkbox chk_useContext "Render with Background Objects" checked:false align:#left
        listbox lb_contextObjs "Always Visible Objects:" height:3 readOnly:true
        button btn_addContext "Add Selected" width:125 align:#left across:2 toolTip:"Select objects in viewport and click here"
        button btn_remContext "Remove Item" width:125 align:#right
    )

    group "4. Selection Mode"
    (
        radiobuttons rdo_mode labels:#("Render Selected Objects Only", "Render All Geometry in Scene") default:1 align:#left
    )

    group "5. Execution"
    (
        progressbar pb_process color:green value:0
        button btn_render "START BATCH RENDER" width:260 height:40 highlightColor:(color 0 200 0)
    )

    group "Debug Log"
    (
        edittext et_log "" height:100 readOnly:true scrollbars:#vertical
    )

    -- // VARIABLES //
    local outDir = undefined
    local contextNodes = #() -- Array to store background objects
    
    -- // FUNCTIONS //

    fn log msg =
    (
        local entry = ((getLocalTime()) as string) + " - " + msg + "\n"
        et_log.text = entry + et_log.text 
    )

    fn populateCameras =
    (
        local cams = for c in cameras where classof c != Target collect c.name
        ddl_cameras.items = cams
        if cams.count > 0 do ddl_cameras.selection = 1
    )

    fn updateContextList =
    (
        -- Refresh the listbox names
        lb_contextObjs.items = for n in contextNodes collect n.name
    )

    fn toggleUIState state =
    (
        btn_browse.enabled = state
        btn_render.enabled = state
        rdo_mode.enabled = state
        ddl_cameras.enabled = state
        btn_addContext.enabled = state
        btn_remContext.enabled = state
    )

    -- // EVENT HANDLERS //

    on outputRollout open do
    (
        populateCameras()
        log "Script initialized."
        log "Please select an output folder."
    )

    on btn_refresh pressed do
    (
        populateCameras()
        log "Camera list refreshed."
    )

    on chk_useRenderSettings changed state do
    (
        lbl_hint.enabled = not state
    )

    -- Context/Background Handlers
    on btn_addContext pressed do
    (
        local sel = selection as array
        if sel.count == 0 then 
        (
            messageBox "Please select objects in the viewport first."
        )
        else
        (
            for s in sel do appendIfUnique contextNodes s
            updateContextList()
            chk_useContext.checked = true
            log ("Added " + sel.count as string + " objects to context.")
        )
    )

    on btn_remContext pressed do
    (
        if lb_contextObjs.selection > 0 do
        (
            deleteItem contextNodes lb_contextObjs.selection
            updateContextList()
        )
    )

    on btn_browse pressed do
    (
        local rawPath = getSavePath caption:"Select Folder for Thumbnails" initialDir:(maxFilePath)
        if rawPath != undefined do
        (
            outDir = rawPath + "\\"
            et_path.text = outDir
            log ("Output set to: " + outDir)
        )
    )

    on btn_render pressed do
    (
        -- Validation
        if outDir == undefined do (messageBox "Please select an output folder first." title:"Error"; return false)
        if ddl_cameras.selected == undefined do (messageBox "No camera selected. Please create a camera." title:"Error"; return false)
        
        -- Collection
        local objsToRender = #()
        if rdo_mode.state == 1 then
            objsToRender = selection as array
        else
            objsToRender = for o in geometry collect o

        -- Filter out context objects from the render list to avoid rendering the floor as a thumbnail itself
        -- (Optional: remove this block if you actually WANT to render the floor as a separate thumbnail)
        local filteredObjs = #()
        for o in objsToRender do
        (
            local isContext = (findItem contextNodes o) != 0
            if not isContext do append filteredObjs o
        )
        objsToRender = filteredObjs

        if objsToRender.count == 0 do (messageBox "No objects found to render." title:"Error"; return false)

        -- Confirmation
        local confirmMsg = "Ready to render " + (objsToRender.count as string) + " objects.\nProceed?"
        if queryBox confirmMsg title:"Confirm Batch" then
        (
            toggleUIState false
            log "Starting Batch Process..."
            
            -- Store current scene state
            local previousSelection = selection as array
            local hiddenState = for o in objects collect o.isHidden
            local originalWidth = renderWidth
            local originalHeight = renderHeight
            
            -- Get Camera Node
            local camNode = getNodeByName ddl_cameras.selected

            -- Override settings if requested
            if not chk_useRenderSettings.checked do
            (
                renderWidth = 512
                renderHeight = 512
                log "Overriding settings: Res set to 512x512"
            )

            disableSceneRedraw()
            
            try
            (
                -- Hide Geometry Only (Keeps Lights/Cameras visible)
                hide geometry
                
                for i = 1 to objsToRender.count do
                (
                    local obj = objsToRender[i]
                    
                    -- Update UI
                    pb_process.value = (100.0 * i / objsToRender.count)
                    log ("Rendering (" + i as string + "/" + objsToRender.count as string + "): " + obj.name)
                    
                    -- Isolate Target Object
                    unhide obj
                    
                    -- Isolate Context/Background Objects
                    if chk_useContext.checked do
                    (
                        for cNode in contextNodes do 
                        (
                            if isValidNode cNode do unhide cNode
                        )
                    )
                    
                    -- Define Output Filename
                    local safeName = substituteString obj.name " " "_"
                    local outFile = outDir + safeName + ".jpg"
                    
                    -- RENDER COMMAND
                    render camera:camNode outputfile:outFile vfb:off progressbar:true quiet:true
                    
                    -- Re-hide for next loop
                    hide obj
                )
                
                log "Batch Render Complete!"
                messageBox "Batch Processing Finished Successfully!"
            )
            catch
            (
                log ("ERROR: " + getCurrentException())
                messageBox "An error occurred. Check the log."
            )
            
            -- RESTORE SCENE STATE
            log "Restoring scene state..."
            
            if not chk_useRenderSettings.checked do
            (
                renderWidth = originalWidth
                renderHeight = originalHeight
            )

            max unhide all 
            for i = 1 to objects.count do objects[i].isHidden = hiddenState[i]
            
            select previousSelection
            enableSceneRedraw()
            redrawViews()
            toggleUIState true
        )
    )
)

createDialog outputRollout