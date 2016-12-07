# -----------------------------------------------------------------------------
#    Script: ISEAddOns.psm1
#    Author: Marlon Rodriguez
#    Date: 02/26/2014 09:37:05
#    Keywords:
#    Comments:
#
# -----------------------------------------------------------------------------
Set-StrictMode -Version Latest

Function Add-ISEComment
{
<#
   .Synopsis
    This function adds the comment symbol to the selected text in ISE.

   .DESCRIPTION
    This command does this by taking the selected text in ISE and line by line adds a comment at the beginning.

   .Notes
    AUTHOR: Marlon.Rodriguez
    LASTEDIT: 02/18/2014 12:12:47

#>
[CmdletBinding()]
PARAM()

    $text = $psISE.CurrentFile.editor.selectedText

    foreach ($l in $text -split [environment]::newline)
    {
        $newText += "{0}{1}" -f ("#" + $l),[environment]::newline
    }

    $psISE.CurrentFile.Editor.InsertText($newText)
}

Function Remove-ISEComment
{
<#
   .Synopsis
    This function removes the comment symbol to the selected text in ISE.

   .DESCRIPTION
    This command does this by taking the selected text in ISE and line by line removes a comment symbol from the beginning of each line.

   .Notes
    AUTHOR: Marlon Rodriguez
    LASTEDIT: 02/18/2014 12:12:47

#>
[CmdletBinding()]
PARAM()

    $text = $psISE.CurrentFile.editor.selectedText
    foreach ($l in $text -split [environment]::newline)
    {
        $newText += "{0}{1}" -f ($l -replace '#',''),[environment]::newline
    }
    $psISE.CurrentFile.Editor.InsertText($newText)
}

#Remove-ISEComment -Verbose -Debug