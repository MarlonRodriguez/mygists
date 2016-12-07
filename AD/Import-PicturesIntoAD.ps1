<#
	.SYNOPSIS
		Imports user pictures into AD by leveraging the badge system database while filtering the accounts to be modified.

	.DESCRIPTION
		Use the script with the filtering parameters to greatly diminish the amount of accounts that will be affected by the change.  It will get the binary
		data from the badge system database ( and convert it to bitmap in order to resize if needed) which can then be written into a JPEG file or imported directly.
		If resizing down the picture to the number entered for "DesiredPixSize", or 96 which is the default otherwise, this will lower the amount of data precessed.
	
	.PARAMETER TargetDomain
		Targeted domain for importing the pictures.
	
	.PARAMETER Filter
		Filter to be used on the Target Domain. e.g.: Account doesnt have a pic, has employeeId, has HomeDB (Mailbox), etc.

	.PARAMETER LenelDB
		Connection details for the badge database that contains the pictures use: Server(USE FQDN)\Instance(optional if using default)\DatabaseName
	
	.PARAMETER Width
		Integer number that sets the pixel dimensions that will be used to import the image. e.g.: 96 (Default) for 96x96 image.
	
	.PARAMETER Height
		Integer number that sets the pixel dimensions that will be used to import the image. e.g.: 96 (Default) for 96x96 image.
	
	.PARAMETER NumberOfUsers
		Number of users to affect with this change at a time.  Default is 100 but can be anywhere from 1-50K users.

	.EXAMPLE
		Import-PicturesIntoAD.ps1 -TargetDomain mydomainlab.org -LenelDB LABSQL001.mydomain.lab\AccessControl -NumberOfUsers 200 -Verbose -force

		This will search for users matching the Filter paramater in the mydomainlab.org domain and connecting to the LABSQL001 database server and the AccessControl DB.
		It will only perform the picture import on a maximum of 200 users.

	.NOTES
		AUTHOR: Marlon.Rodriguez
		VERSION: 1.0
		LASTEDIT: 03/11/2016 11:37:26

	.LINK
		http://stash.mydomain.com:8990/projects/repos/powershell/browse/AD

#>
[CmdletBinding(
	SupportsShouldProcess=$True,
	ConfirmImpact="High"
)]
PARAM(
	[Parameter( Mandatory = $True,
				Position = 0,
				ValueFromPipeline = $False,
				HelpMessage = "Domain where the pictures will be imported")]
	[Alias("Target","D","Domain","TD")]
	[ValidateNotNullOrEmpty()] 
	[ValidatePattern("(\w+\.){1,3}\w+")]
	[String]
	$TargetDomain,
	
	[Parameter( Mandatory = $False,
				Position = 1,
				ValueFromPipeline = $False,
				HelpMessage = "Filter to be used for the target domain.")]
	[Alias("ADFilter","F")]
	[ValidateNotNullOrEmpty()]
	[String]
	$Filter = {employeeID -like "*" -and homeMDB -like "*" -and thumbnailPhoto -notlike "*"}, #Users with mailbox, employeeID, and not already have a picture loaded
		
	[Parameter( Mandatory = $True,
				Position = 2, 
				ValueFromPipeline = $False,
				HelpMessage="Enter the database connection details in the form: ServerFQDN\Instance\DatabaseName.  Instance can be skipped if using default."
	)]
	[Alias("LenelDatabase","Lenel","BadgeDB")]
	[ValidateNotNullOrEmpty()]
	[ValidatePattern("(\w+\.){1,3}\w+\.\w+\\(\w+\\)?\w+")] #Enter Server-FQDN\Instance\DBName where the Instance name could be ommited if using the default
	[String]
	$LenelDB,
	
	[Parameter( Mandatory = $False,
				Position = 3, 
				ValueFromPipeline = $False,
				HelpMessage="Number of pixels to format the picture's width.  Default is 96 (96x96)"
	)]
	[Alias("W")]
	[ValidateRange(50,100)]
	[int]
	$Width = 96,
	
	[Parameter( Mandatory = $False,
				Position = 4, 
				ValueFromPipeline = $False,
				HelpMessage="Number of pixels to format the picture's height.  Default is 96 (96x96)"
	)]
	[Alias("H")]
	[ValidateRange(50,100)]
	[int]
	$Height = 96,

	[Parameter( Mandatory = $False,
				Position = 5, 
				ValueFromPipeline = $False,
				HelpMessage="Number of users to process at this time.  Default: 100"
	)]
	[Alias("Users","UserCount","U","NumberOfUsersToModify")]
	[ValidateRange(1,50000)]
	[int]
	$NumberOfUsers = 100,

	[Parameter( Mandatory = $False,
				Position = 6,
				ValueFromPipeline = $False,
				HelpMessage="Force changes without prompting."
	)]
	[Switch]
	$Force = $False
		
)

	$StartTime = Get-Date

	$Verbose = If ($PSCmdlet.MyInvocation.BoundParameters["Verbose"]) {$True} else {$False}
	$Debug = If ($PSCmdlet.MyInvocation.BoundParameters["Debug"]) {$True; $DebugPreference = "Continue"} else {$False}
	$WhatIf = If ($PSCmdlet.MyInvocation.BoundParameters["WhatIf"]) {$True} else {$False}
	$Confirm = If ($PSCmdlet.MyInvocation.BoundParameters["Confirm"]) {$True} else {$False}
	
	$Assem = @(
		"System.Data",
		"System.Drawing"
	) 


	#The following is the C# code creating a class to handle getting the pics from the database,
	#Saving it to a file, and modifying it's size while keeping aspect ratio.
	#You only need to know about the two main methods: SavePic and ProcessJPEG.  They both write 
	#to the console on failure.
	#Methods:
	#
	#	int GetUserPic(string sEmployeeID, ref byte[] bArrImage, int iWidth, int iHeight)
	#
	#Returns: 		1 on failure 0 on success.
	#Description: 	It saves a jpeg to the path provided if it was able to find one.
	#Inputs:		Employee ID, a byte array by reference to contain the image, width, and height
	#				of the desired picture. 
	#Notes:			Please note that if multiple results are returned from the database it will 
	#				ignore them and return fail. Only unique 1 row results are used. Keep that 
	#				in mind if you see failures. This was done to make sure that only there was 
	#				1 unique record to return and avoid as much as possible saving the wrong 
	#				picture with the employee id provided. The badge database is updated manually
	#				sometimes so mistakes will happen.
	#
	#	byte [] processJpeg( byte [] bPic, int width, int height)
	#
	#Returns:		Byte array containing the image.
	#Description:	Modifies the picture as close as possible to the pixel size provided while 
	#				keeping the aspect ratio.  
	#Inputs:		Byte array image, width, and height.
	#Notes:			It will always resize to the highest value provided with the second being less.
	#				This is to keep the aspect ratio without loosing part of the picture.  Meaning
	#				that, if the aspect ratio of the jpeg is a perfect square then you 
	#				will get the exact size you wanted.  If not, you could ask for a 96X96 pixel 
	#				size and will get back 96x94 or 94x96.
	#
	#Examples:
	#
	#Add-Type -ReferencedAssemblies $Assem -TypeDefinition $SourceCode -Language CSharp
	#$result = [mydomain.IT.Infrastructure.BadgePicDumper.GetBadgePic]::GetUserPic( sEmployeeID, out $bArrImage, $Width, $Height)
	#$result = [mydomain.IT.Infrastructure.BadgePicDumper.GetBadgePic]::processJPEG( $bArrImage, 96, 96)
	#
	$SourceCode = @"
using System;
using System.Data.SqlClient;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

namespace mydomain.IT.Infrastructure.BadgePicDumper
{
	public static class GetBadgePic
	{
		/// <summary>
		/// This function will try to get a user pic from the badge database and resize it, returning it by reference parameter.
		/// </summary>
		/// <param name="sEmployeeID">Used to get the user pic from the database.</param>
		/// <param name="bArrImage">By reference paramater of type Byte Array containing the image.</param>
		/// <returns>Returns error number or 0(zero) if successful </returns>
		public static int GetUserPic(string sEmployeeID, ref byte[] bArrImage, int iWidth, int iHeight)
		{
			int retValue = 0;
			bArrImage = null;
			try
			{
				bArrImage = GetPic(sEmployeeID);

				if (bArrImage != null)
				{
					bArrImage = processJpeg(bArrImage, iWidth, iHeight);
				}
				else
				{
					retValue = 1;
				}
			}
			catch (Exception e)
			{
				retValue = e.HResult;
				Console.WriteLine(e.ToString());
			}
			return retValue;
		}

		/// <summary>
		/// Gets the user pic from the Badge database using empID, returns pic as byte[] or null.
		/// </summary>
		/// <param name="empID">EmployeeID to match against the Lenel EMP.SSNO field.</param>
		/// <returns>The binary data (byte[]) for the user's pic.</returns>
		public static byte[] GetPic(string empID)
		{
			byte[] byTemp = null;
			SqlConnection sqlCon = null;
			SqlDataReader thisReader = null;
			string sqlConnection = "Data Source=SERVERHERE;Initial Catalog=DATABASEHERE;Integrated Security=True";

			try
			{
				sqlCon = new SqlConnection(sqlConnection);
				sqlCon.Open();

				SqlCommand sqlCommand = sqlCon.CreateCommand();
				sqlCommand.CommandText = "SELECT t1.LNL_BLOB " +
											"FROM MMOBJS AS t1 " +
											"RIGHT OUTER JOIN (SELECT ID " +
											"						FROM EMP " +
											"						WHERE SSNO LIKE '" + empID + "'" +
											"						GROUP BY ID HAVING COUNT(ID) = 1) AS t2 " +
											"ON t1.EMPID = t2.ID " +
											"WHERE (t1.Type = 0)";
				thisReader = sqlCommand.ExecuteReader(System.Data.CommandBehavior.CloseConnection);

				if (thisReader.Read())
				{
					byTemp = (byte[])thisReader[0];
				}
			}
			catch (SqlException e)
			{
				Console.WriteLine(e.Message);
			}
			finally
			{
				thisReader.Close();
				sqlCon.Close();
			}

			return byTemp;
		}

		/// <summary>
		/// This function resizes the specified image object to the desired size in pixels and returns the new one.
		/// </summary>
		/// <param name="imgToResize">Image object that will be resized.</param>
		/// <param name="size">Size object that contains width and height for the returned image.</param>
		/// <returns>Image object with the new dimensions.</returns>
		public static Image resizeImage(Image imgToResize, Size size)
		{
			int sourceWidth = imgToResize.Width;
			int sourceHeight = imgToResize.Height;

			float nPercent = 0;
			float nPercentW = 0;
			float nPercentH = 0;

			nPercentW = ((float)size.Width / sourceWidth);
			nPercentH = ((float)size.Height / sourceHeight);

			if (nPercentH > nPercentW)
				nPercent = nPercentH;
			else
				nPercent = nPercentW;

			int destWidth = (int)(sourceWidth * nPercent);
			int destHeight = (int)(sourceHeight * nPercent);

			Bitmap b = new Bitmap(destWidth, destHeight);
			Graphics g = Graphics.FromImage((Image)b);
			g.InterpolationMode = InterpolationMode.HighQualityBilinear;
			//HighQualityBicubic = High quality
			//HighQualityBilinear = Medium quality
			//NearestNeighbor = Low quality

			g.DrawImage(imgToResize, 0, 0, destWidth, destHeight);
			g.Dispose();

			return b;
		}

		/// <summary>
		/// This method resizes the image in byte[] to the specified size while keeping the aspect ratio and returns it.
		/// </summary>
		/// <param name="bPic">Image that will be processed.</param>
		/// <param name="width">Desired width.</param>
		/// <param name="height">Desired height.</param>
		public static byte [] processJpeg( byte [] bPic, int width, int height)
		{
			Image img = Image.FromStream(new System.IO.MemoryStream(bPic));
			Image imgToSave;
			Size neededSize = new Size(width, height);
			System.IO.MemoryStream tempJpeg = null;

			if (img.Height > neededSize.Height || img.Width > neededSize.Width)
			{
				imgToSave = resizeImage(img, neededSize);
				//img.Dispose();//release to avoid access errors when overwritting file...


				// Encoder parameter for image quality
				EncoderParameter qualityParam = new EncoderParameter(Encoder.Quality, 100L);

				// Jpeg image codec
				ImageCodecInfo jpegCodec = getEncoderInfo("image/jpeg");

				if (jpegCodec == null)
					return tempJpeg.ToArray();

				EncoderParameters encoderParams = new EncoderParameters(1);
				encoderParams.Param[0] = qualityParam;
				tempJpeg = new System.IO.MemoryStream();
				imgToSave.Save(tempJpeg, jpegCodec, encoderParams);
			}
			return tempJpeg.ToArray();
		}

		/// <summary>
		/// Loads and gets the encoder for the selected media codec/mime type.
		/// </summary>
		/// <param name="mimeType">Select the name for the image codec to be loaded. i.e. "image/jpeg"</param>
		/// <returns>Returns the loaded codec to be used or null if it failed to load.</returns>
		private static ImageCodecInfo getEncoderInfo(string mimeType)
		{
			// Get image codecs for all image formats
			ImageCodecInfo[] codecs = ImageCodecInfo.GetImageEncoders();

			// Find the correct image codec
			for (int i = 0; i < codecs.Length; i++)
				if (codecs[i].MimeType == mimeType)
					return codecs[i];
			return null;
		}
	}
}

"@


$Database = $LenelDB | Select-Object -Property @{N="Server";E={$LenelDB.TrimEnd("\" + $LenelDB.Split("\")[-1]).Replace("\","\\")}},@{N="DBName";E={$LenelDB.Split("\")[-1]}}
Write-Verbose $Database
$TargetUsers = Get-ADUser -Server $TargetDomain -Properties employeeID,thumbnailPhoto -Filter $Filter
Write-Verbose "Processing: $($TargetUsers.Count) users"
$SourceCode = $SourceCode.Replace("SERVERHERE",$Database.Server).Replace("DATABASEHERE",$Database.DBName)
Write-Verbose $SourceCode
Write-Verbose "Target Domain: $TargetDomain"
Write-verbose "Max users to Process: $NumberOfUsers and Found: $($TargetUsers.Count) that match the filter."
Write-Verbose "Using filter: $Filter"
Write-Verbose "Picture Size: $(""" + $Width + "x" + $Height)"

$TotalBytes = 0
$UsersAffected = 0

Add-Type -ReferencedAssemblies $Assem -TypeDefinition $SourceCode -Language CSharp
Write-Verbose "`tNew type with the C# code should now be added..."
foreach ($item in $TargetUsers[0..$NumberOfUsers]) #only affect as many users as the Max set.
{

	If ($Force -or $pscmdlet.ShouldProcess($TargetDomain,"Import user pictures into $TargetDomain for: $($item.Name)"))
	{
		[Byte[]] $UserPic = $null
		Write-Verbose "`tUser being processed: $($item.Name)..."
        Try
		{
            $UserPicResult = [mydomain.IT.Infrastructure.BadgePicDumper.GetBadgePic]::GetUserPic( $item.employeeID, [ref] $UserPic, $Width, $Height)
            if ($UserPicResult -eq 0 -and $UserPic -ne $null)
			{
                $item | Set-ADUser -Add @{'thumbnailPhoto'=$UserPic}
                Write-Verbose "`t`tUser with empID: $($item.employeeID) should now hava a pic of $($UserPic.Length) bytes in size."
                $TotalBytes += $UserPic.Length
                $UsersAffected += 1
            } else {
                Write-Warning "`t`tNo photo found for user: $($item.Name + " with empID: " + $item.employeeID). Either the empID didnt match or more than one record was returned."
            }
        } Catch {
            $ErrorMessage = $_.Exception.Message
			$FailedItem = $_.Exception.ItemName
			Write-Error "`t`tFailed to update user with empID: $($item.employeeID)"
			Write-Error $FailedItem
			Write-Error $ErrorMessage
			break
        } Finally {}
	}
}
Write-Verbose "Processed $UsersAffected users with $($TotalBytes/1KB) Kilobytes in total."

Write-Output "`r`n`r`n****** Script Duration: $(New-TimeSpan ($StartTime) (Get-Date)) ******"
