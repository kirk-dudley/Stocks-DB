$StartDir = "D:\Stock_Data\EODData\EODData - Dailys"
$HasOpenInt = "D:\Stock_Data\EODData\EODData_Dailys_Sorted\HasOpenInt"
$NoOpenInt = "D:\Stock_Data\EODData\EODData_Dailys_Sorted\NoOpenInt"
#$archivedir = "D:\Stock_Data\Archived\EODData\EODData Historic Zip"
#$archivefile = ""
$movedir = ""
$files = Get-ChildItem $StartDir -Filter "*.csv" -Recurse



#if the target directories don't exist, creates them, else clears out existing files
if (Test-Path -Path $HasOpenInt) {
        $removedir = $HasOpenInt + '\*.*'
        Remove-Item $removedir 
} else {
    New-Item -Path $HasOpenInt -ItemType Directory -Force
}

if (Test-Path -Path $NoOpenInt) {
        $removedir = $NoOpenInt + '\*.*'
        Remove-Item $removedir 
} else {
    New-Item -Path $NoOpenInt -ItemType Directory -Force
}


FOREACH ($f IN $files){
    SWITCH -WILDCARD ($F.Name) {
#Files without the openint column
        "AMEX*.csv" {$movedir = $NoOpenInt}
        "ASX*.csv" {$movedir = $NoOpenInt}
        "EUREX*.csv" {$movedir = $NoOpenInt}
        "FOREX*.csv" {$movedir = $NoOpenInt}
        "INDEX*.csv" {$movedir = $NoOpenInt}
        "LSE*.csv" {$movedir = $NoOpenInt}
        "NASDAQ*.csv" {$movedir = $NoOpenInt}
        "NYSE*.csv" {$movedir = $NoOpenInt}
        "OTCBB*.csv" {$movedir = $NoOpenInt}
        "SGX*.csv" {$movedir = $NoOpenInt}
        "TSX*.csv" {$movedir = $NoOpenInt}
        "TSXV*.csv" {$movedir = $NoOpenInt}
        "USMF*.csv" {$movedir = $NoOpenInt}

#Files with the openint column

        "CFE*.csv" {$movedir = $HasOpenInt}
        "LIFFE*.csv" {$movedir = $HasOpenInt}
        "MGEX*.csv" {$movedir = $HasOpenInt}
        "NYBOT*.csv" {$movedir = $HasOpenInt}
        "WCE*.csv" {$movedir = $HasOpenInt}


#if the file isn"t in either list, $movedir will be set to an empty string to avoid attempting to move undefined files
        default {$movedir = ""}
        }

#moves to the target folder, ignoring files without a valid target directory
    IF ($movedir -ne "") {Move-Item -Path $f.fullname -destination $movedir -Force
                          }
}   
