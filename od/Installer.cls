/// Installer for the container release of PythonGateway
Class od.Installer
{

XData Install [ XMLNamespace = INSTALLER ]
{
<Manifest>
  <Var Name="pwd" Value="SYS"/> 
  <User Username="SuperUser" ChangePassword="0" PasswordVar="pwd" Roles="%All" Enabled="1"/>
  <Default Name="NAMESPACE" Value="PYTHON"/>
  <Default Name="DBNAME" Value="${NAMESPACE}"/>
  <Default Name="SOURCESPATH" Dir='#{$system.Util.GetEnviron("SRC_DIR")}' />
  <Default Name="RESOURCE" Value="%DB_${DBNAME}" /> 
  <Namespace Name="${NAMESPACE}" Ensemble="1">

    <Import File="${SOURCESPATH}od" Recurse="1"/>
    <Import File="/usr/irissys/csp/python/index.csp"/>
    <Import File="/usr/irissys/csp/python/camera.csp"/>
    <Import File="/usr/irissys/csp/python/result.csp"/>    
    <Import File="/usr/irissys/csp/python/WorkFlowForm.csp"/>
    <Import File="/usr/irissys/csp/python/EscalatedWorkFlowForm.csp"/>


	<CSPApplication Url="/csp/${Namespace}" Directory="${CSPDIR}${Namespace}" AutoCompile="1" />
     
    <Log Level="1" Text="Configuring BPL Editor"/>
    <Invoke Class="od.Installer" Method="PatchBP" CheckStatus="true"/>
        
    <Log Level="1" Text="Enabling OS level Authentication"/>
    <Invoke Class="od.Installer" Method="OSAuth" CheckStatus="true"/>
    
	<Log Level="1" Text="Enabling Analytics"/>
	<Invoke Class="od.Installer" Method="EnableAnalytics" CheckStatus="true">
      <Arg Value="/csp/python/"/>
    </Invoke>

	<Log Level="1" Text="Configuring REST"/>
    <Invoke Class="od.Installer" Method="CreateREST">
   <Arg Value="${NameSpace}"/>
   <Arg Value="/rest/imageod"/>
   <Arg Value="od.RestServer"/>
   </Invoke>

	<Log Level="1" Text="Configuring Workflow Rules"/>
    <Invoke Class="od.Installer" Method="AddWorkflowRules"/>
    <Production Name="od.Production"  AutoStart="1" />
  </Namespace>
</Manifest>
}

ClassMethod Setup(ByRef pVars, pLogLevel As %Integer = 3, pInstaller As %Installer.Installer, pLogger As %Installer.AbstractLogger) As %Status [ CodeMode = objectgenerator, Internal ]
{
  Quit ##class(%Installer.Manifest).%Generate(%compiledclass, %code, "Install")
}

/// Enable OS Authentication
ClassMethod OSAuth() As %Status
{
	new $namespace
	set $namespace = "%SYS"
	set sc = ##Class(Security.System).Get($$$SystemSecurityName,.properties)
	quit:$$$ISERR(sc) sc
	
	set autheEnabled = properties("AutheEnabled")
	quit:'$data(autheEnabled) $$$ERROR($$$PropertyDoesNotExist, "AutheEnabled")
	set properties("AutheEnabled") = $ZBOOLEAN(+autheEnabled, $$$AutheOS, 7)
	set sc = ##Class(Security.System).Modify($$$SystemSecurityName, .properties) 
	
	quit sc
}

ClassMethod LoadZRoutines(dir As %String) As %Status
{
	new $namespace
	set $namespace = "%SYS"
	
	set dir = ##class(%File).NormalizeDirectory(dir)
	set sc = $system.OBJ.ImportDir(dir, "*.xml", "c")
	quit sc
}

/// Add magnifying glass to Annotation
/// zw ##class(od.Installer).PatchBP()
ClassMethod PatchBP() As %Status
{
	set class = "EnsPortal.BPLEditor"
	set patch = "<!-- PATCH -->"
	$$$QuitOnError(##class(%Compiler.UDL.TextServices).GetTextAsString(, class, .code))
	quit:$find(code, patch) $$$OK 
		
	set oldNS = $namespace
	new $namespace
	set $namespace = "%SYS"
	
	set db = ##class(SYS.Database).%OpenId($system.Util.ManagerDirectory() _ "enslib")
	set bk = db.ReadOnly
	set db.ReadOnly = 0 
	
	$$$QuitOnError(db.%Save())
	
	set $namespace = oldNS
	set line = "<textarea id=""aAnnotation"" label=""Annotation"" rows=""3"" cols=""35"" onchange=""zenPage.activityChange(1);"" onkeyup=""zenPage.textControlKeyUp(zenEvent,zenThis);"" onkeydown=""zenPage.textControlKeyDown(zenThis);""/>"
	set button = "<image src=""deepsee/zoom_16.png"" onclick=""zenPage.editPropertyValue('aAnnotation','code');"" title=""Edit value""/>"
	
	set code = $replace(code, line, line _ $$$NL _ patch _ button)
	
	$$$QuitOnError(##class(%Compiler.UDL.TextServices).SetTextFromString(, class, code))
	$$$QuitOnError($system.OBJ.Compile(class))
	
	set $namespace = "%SYS"
	
	set db.ReadOnly = bk 
	quit db.%Save()
}

ClassMethod CreateREST(namespace2 As %String, url As %String, dispatch As %String) As %Status
{
	#dim sc As %Status = $$$OK
    new $namespace
    set $namespace = "%SYS"
    if '##class(Security.Applications).Exists(url) {
        set props("AutheEnabled") = $$$AutheCache
        set props("NameSpace") = "PYTHON"
        set props("IsNameSpaceDefault") = $$$NO
        set props("DispatchClass") = dispatch
        set props("MatchRoles")=":" _ $$$AllRoleName
        set sc = ##class(Security.Applications).Create(url, .props)
    }
    quit sc
}

ClassMethod EnableAnalytics(pCSPName As %String, url As %String) As %Status
{
  new $namespace
  znspace "%SYS"
  set props("DeepSeeEnabled")=1
  do ##class(Security.Applications).Modify(pCSPName,.props)
  quit $$$OK
}

ClassMethod AddWorkflowRules() As %Status
{
  do ##class(EnsLib.Workflow.UserDefinition).CreateUser("SuperUser","SU Account") 
  do ##class(EnsLib.Workflow.RoleDefinition).CreateRole("OrderTeam")
	do ##class(EnsLib.Workflow.RoleDefinition).AddUserToRole("OrderTeam","SuperUser")
}

}
