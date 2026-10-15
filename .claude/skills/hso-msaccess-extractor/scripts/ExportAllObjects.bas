' ==============================================================================
' MS Access Object Export Module
' ==============================================================================
' Exports all database objects (Forms, Reports, Modules, Macros, Queries)
' to text files using the undocumented SaveAsText function.
'
' USAGE:
' 1. Open the Access database you want to export
' 2. Press Alt+F11 to open VBA Editor
' 3. Insert > Module
' 4. Paste this code into the module
' 5. Press F5 or run ExportAllObjects from Immediate Window:
'    Call ExportAllObjects("C:\Output\Path")
'
' Or run individual export functions:
'    Call ExportForms("C:\Output\Path\Forms")
'    Call ExportReports("C:\Output\Path\Reports")
'    Call ExportModules("C:\Output\Path\Modules")
'    Call ExportMacros("C:\Output\Path\Macros")
'    Call ExportQueries("C:\Output\Path\Queries")
' ==============================================================================

Option Compare Database
Option Explicit

' ==============================================================================
' MAIN EXPORT FUNCTION
' ==============================================================================
Public Sub ExportAllObjects(Optional sExportPath As String = "")
    Dim sBasePath As String
    Dim db As DAO.Database
    Dim startTime As Date
    Dim formCount As Long, reportCount As Long, moduleCount As Long
    Dim macroCount As Long, queryCount As Long

    startTime = Now

    ' Set default export path if not provided
    If sExportPath = "" Then
        sBasePath = CurrentProject.Path & "\Export_" & Format(Now, "yyyymmdd_hhnnss")
    Else
        sBasePath = sExportPath
    End If

    ' Create main export folder
    CreateFolderIfNotExists sBasePath

    Debug.Print "=============================================="
    Debug.Print "MS Access Object Export"
    Debug.Print "=============================================="
    Debug.Print "Database: " & CurrentProject.Name
    Debug.Print "Export to: " & sBasePath
    Debug.Print "Started: " & Format(startTime, "yyyy-mm-dd hh:nn:ss")
    Debug.Print ""

    ' Export all object types
    formCount = ExportForms(sBasePath & "\Forms")
    reportCount = ExportReports(sBasePath & "\Reports")
    moduleCount = ExportModules(sBasePath & "\Modules")
    macroCount = ExportMacros(sBasePath & "\Macros")
    queryCount = ExportQueries(sBasePath & "\Queries")

    ' Print summary
    Debug.Print ""
    Debug.Print "=============================================="
    Debug.Print "EXPORT SUMMARY"
    Debug.Print "=============================================="
    Debug.Print "Forms:   " & formCount
    Debug.Print "Reports: " & reportCount
    Debug.Print "Modules: " & moduleCount
    Debug.Print "Macros:  " & macroCount
    Debug.Print "Queries: " & queryCount
    Debug.Print "----------------------------------------------"
    Debug.Print "Total:   " & (formCount + reportCount + moduleCount + macroCount + queryCount)
    Debug.Print ""
    Debug.Print "Completed: " & Format(Now, "yyyy-mm-dd hh:nn:ss")
    Debug.Print "Duration: " & Format(Now - startTime, "nn:ss")
    Debug.Print "=============================================="

    MsgBox "Export complete!" & vbCrLf & vbCrLf & _
           "Forms: " & formCount & vbCrLf & _
           "Reports: " & reportCount & vbCrLf & _
           "Modules: " & moduleCount & vbCrLf & _
           "Macros: " & macroCount & vbCrLf & _
           "Queries: " & queryCount & vbCrLf & vbCrLf & _
           "Output: " & sBasePath, vbInformation, "Export Complete"
End Sub

' ==============================================================================
' EXPORT FORMS
' ==============================================================================
Public Function ExportForms(sExportPath As String) As Long
    Dim obj As AccessObject
    Dim count As Long

    CreateFolderIfNotExists sExportPath
    count = 0

    Debug.Print "Exporting Forms..."

    For Each obj In CurrentProject.AllForms
        On Error Resume Next
        Application.SaveAsText acForm, obj.Name, sExportPath & "\" & SanitizeFileName(obj.Name) & ".txt"
        If Err.Number = 0 Then
            Debug.Print "  [OK] " & obj.Name
            count = count + 1
        Else
            Debug.Print "  [ERROR] " & obj.Name & " - " & Err.Description
            Err.Clear
        End If
        On Error GoTo 0
    Next obj

    Debug.Print "  Forms exported: " & count
    ExportForms = count
End Function

' ==============================================================================
' EXPORT REPORTS
' ==============================================================================
Public Function ExportReports(sExportPath As String) As Long
    Dim obj As AccessObject
    Dim count As Long

    CreateFolderIfNotExists sExportPath
    count = 0

    Debug.Print "Exporting Reports..."

    For Each obj In CurrentProject.AllReports
        On Error Resume Next
        Application.SaveAsText acReport, obj.Name, sExportPath & "\" & SanitizeFileName(obj.Name) & ".txt"
        If Err.Number = 0 Then
            Debug.Print "  [OK] " & obj.Name
            count = count + 1
        Else
            Debug.Print "  [ERROR] " & obj.Name & " - " & Err.Description
            Err.Clear
        End If
        On Error GoTo 0
    Next obj

    Debug.Print "  Reports exported: " & count
    ExportReports = count
End Function

' ==============================================================================
' EXPORT MODULES
' ==============================================================================
Public Function ExportModules(sExportPath As String) As Long
    Dim obj As AccessObject
    Dim count As Long

    CreateFolderIfNotExists sExportPath
    count = 0

    Debug.Print "Exporting Modules..."

    For Each obj In CurrentProject.AllModules
        On Error Resume Next
        Application.SaveAsText acModule, obj.Name, sExportPath & "\" & SanitizeFileName(obj.Name) & ".bas"
        If Err.Number = 0 Then
            Debug.Print "  [OK] " & obj.Name
            count = count + 1
        Else
            Debug.Print "  [ERROR] " & obj.Name & " - " & Err.Description
            Err.Clear
        End If
        On Error GoTo 0
    Next obj

    Debug.Print "  Modules exported: " & count
    ExportModules = count
End Function

' ==============================================================================
' EXPORT MACROS
' ==============================================================================
Public Function ExportMacros(sExportPath As String) As Long
    Dim obj As AccessObject
    Dim count As Long

    CreateFolderIfNotExists sExportPath
    count = 0

    Debug.Print "Exporting Macros..."

    For Each obj In CurrentProject.AllMacros
        On Error Resume Next
        Application.SaveAsText acMacro, obj.Name, sExportPath & "\" & SanitizeFileName(obj.Name) & ".txt"
        If Err.Number = 0 Then
            Debug.Print "  [OK] " & obj.Name
            count = count + 1
        Else
            Debug.Print "  [ERROR] " & obj.Name & " - " & Err.Description
            Err.Clear
        End If
        On Error GoTo 0
    Next obj

    Debug.Print "  Macros exported: " & count
    ExportMacros = count
End Function

' ==============================================================================
' EXPORT QUERIES
' ==============================================================================
Public Function ExportQueries(sExportPath As String) As Long
    Dim obj As AccessObject
    Dim count As Long

    CreateFolderIfNotExists sExportPath
    count = 0

    Debug.Print "Exporting Queries..."

    For Each obj In CurrentData.AllQueries
        On Error Resume Next
        Application.SaveAsText acQuery, obj.Name, sExportPath & "\" & SanitizeFileName(obj.Name) & ".sql"
        If Err.Number = 0 Then
            Debug.Print "  [OK] " & obj.Name
            count = count + 1
        Else
            Debug.Print "  [ERROR] " & obj.Name & " - " & Err.Description
            Err.Clear
        End If
        On Error GoTo 0
    Next obj

    Debug.Print "  Queries exported: " & count
    ExportQueries = count
End Function

' ==============================================================================
' EXPORT TABLE STRUCTURE (as text definition)
' ==============================================================================
Public Function ExportTableStructure(sExportPath As String) As Long
    Dim db As DAO.Database
    Dim tdf As DAO.TableDef
    Dim fld As DAO.Field
    Dim idx As DAO.Index
    Dim count As Long
    Dim fileNum As Integer
    Dim filePath As String

    CreateFolderIfNotExists sExportPath
    Set db = CurrentDb
    count = 0

    Debug.Print "Exporting Table Structures..."

    For Each tdf In db.TableDefs
        ' Skip system tables
        If Left(tdf.Name, 4) <> "MSys" And Left(tdf.Name, 1) <> "~" Then
            On Error Resume Next

            filePath = sExportPath & "\" & SanitizeFileName(tdf.Name) & ".txt"
            fileNum = FreeFile

            Open filePath For Output As #fileNum

            Print #fileNum, "TABLE: " & tdf.Name
            Print #fileNum, "========================================"
            Print #fileNum, ""
            Print #fileNum, "FIELDS:"
            Print #fileNum, "----------------------------------------"

            For Each fld In tdf.Fields
                Print #fileNum, "  Name: " & fld.Name
                Print #fileNum, "  Type: " & GetFieldTypeName(fld.Type) & " (" & fld.Type & ")"
                Print #fileNum, "  Size: " & fld.Size
                Print #fileNum, "  Required: " & fld.Required
                If Len(fld.DefaultValue) > 0 Then
                    Print #fileNum, "  Default: " & fld.DefaultValue
                End If
                If Len(fld.ValidationRule) > 0 Then
                    Print #fileNum, "  Validation: " & fld.ValidationRule
                End If
                ' Try to get description
                On Error Resume Next
                Dim desc As String
                desc = fld.Properties("Description")
                If Err.Number = 0 And Len(desc) > 0 Then
                    Print #fileNum, "  Description: " & desc
                End If
                Err.Clear
                On Error GoTo 0
                Print #fileNum, ""
            Next fld

            Print #fileNum, "INDEXES:"
            Print #fileNum, "----------------------------------------"
            For Each idx In tdf.Indexes
                Print #fileNum, "  Name: " & idx.Name
                Print #fileNum, "  Primary: " & idx.Primary
                Print #fileNum, "  Unique: " & idx.Unique
                Print #fileNum, "  Fields: " & GetIndexFields(idx)
                Print #fileNum, ""
            Next idx

            Close #fileNum

            If Err.Number = 0 Then
                Debug.Print "  [OK] " & tdf.Name
                count = count + 1
            Else
                Debug.Print "  [ERROR] " & tdf.Name & " - " & Err.Description
                Err.Clear
            End If
            On Error GoTo 0
        End If
    Next tdf

    Debug.Print "  Table structures exported: " & count
    ExportTableStructure = count
End Function

' ==============================================================================
' HELPER FUNCTIONS
' ==============================================================================

Private Sub CreateFolderIfNotExists(sPath As String)
    On Error Resume Next
    MkDir sPath
    On Error GoTo 0
End Sub

Private Function SanitizeFileName(sName As String) As String
    Dim sResult As String
    Dim i As Long
    Dim c As String

    sResult = sName

    ' Replace invalid filename characters
    sResult = Replace(sResult, "\", "_")
    sResult = Replace(sResult, "/", "_")
    sResult = Replace(sResult, ":", "_")
    sResult = Replace(sResult, "*", "_")
    sResult = Replace(sResult, "?", "_")
    sResult = Replace(sResult, """", "_")
    sResult = Replace(sResult, "<", "_")
    sResult = Replace(sResult, ">", "_")
    sResult = Replace(sResult, "|", "_")

    SanitizeFileName = sResult
End Function

Private Function GetFieldTypeName(iType As Integer) As String
    Select Case iType
        Case 1: GetFieldTypeName = "Boolean"
        Case 2: GetFieldTypeName = "Byte"
        Case 3: GetFieldTypeName = "Integer"
        Case 4: GetFieldTypeName = "Long"
        Case 5: GetFieldTypeName = "Currency"
        Case 6: GetFieldTypeName = "Single"
        Case 7: GetFieldTypeName = "Double"
        Case 8: GetFieldTypeName = "Date/Time"
        Case 9: GetFieldTypeName = "Binary"
        Case 10: GetFieldTypeName = "Text"
        Case 11: GetFieldTypeName = "OLE Object"
        Case 12: GetFieldTypeName = "Memo"
        Case 15: GetFieldTypeName = "GUID"
        Case 16: GetFieldTypeName = "Big Integer"
        Case 101: GetFieldTypeName = "Attachment"
        Case Else: GetFieldTypeName = "Unknown"
    End Select
End Function

Private Function GetIndexFields(idx As DAO.Index) As String
    Dim fld As DAO.Field
    Dim sFields As String

    sFields = ""
    For Each fld In idx.Fields
        If Len(sFields) > 0 Then sFields = sFields & ", "
        sFields = sFields & fld.Name
    Next fld

    GetIndexFields = sFields
End Function

' ==============================================================================
' QUICK TEST - Run this to test on current database
' ==============================================================================
Public Sub QuickExport()
    ' Export to a subfolder of the current database location
    ExportAllObjects CurrentProject.Path & "\Export_" & Format(Now, "yyyymmdd_hhnnss")
End Sub
