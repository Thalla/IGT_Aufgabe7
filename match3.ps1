
function main()
{
    # Get the data (bpmn and wsdl)
    $bpmn = readData("C:\Users\ferocia\Documents\IGT\BPMN\")
    $wsdl = readData("C:\Users\ferocia\Documents\IGT\WSDL_named_changed\WSDL_named\")

    # Get the important words in the bpmn
    $keyWords = getKeyWords -bpmn $bpmn
    $keyWords
    # Get a list with suitable services
    $bestChoices = getSuitableServices -keyWords $keyWords -wsdl $wsdl

    # Show the results
    showBestChoices -number 5 -bestChoices $bestChoices

}

# @return ArrayList with the content of the files in the directory specified by the path
function readData($path)
{
    $elements = (Get-ChildItem -Path $path).name
    
    $list = [System.Collections.Hashtable]@{}

    foreach($element in $elements){
        $cont = Get-Content ($path+$element)
        $element = $element.Replace(" ","") #.Replace('.bpmn|.wsdl','') <- funktioniert nicht
        $list.Add($element,$cont)
    }

    $list

}

# @return eine Liste, die pro Bpmn eine Tabelle mit Schlüsselwörtern und der Häufigkeit ihres Vorkommens enthält
function getKeyWords($bpmn)
{
    $tasks = [System.Collections.Hashtable]@{} # pro Feld alle Tasks einer bpmn-Datei

    # Füllen von tasks
    foreach($name in ($bpmn.keys))
    {
        # Sucht nach: < und (irgendwas außer >) und task und (irgendwas außer >) und name und (entweder=oder =oder= oder = ) und " und (irgendwas außer " und >) und " und (irgendwas außer >) und >
        $regex = '<[^>]*task[^>]*name((=)|( =)|(= )|( = ))"([^">]+)"[^>]*>'
        $task = $bpmn.$name | Where { $_ -match $regex} | foreach{$matches[6]}   # matches[6] entspricht dem Teil zwischen den Anführungszeichen bei name="irgendwas"
        if($task -ne $null)
        {
            $tasks.add($name, $task) > $null
        }
        else{
            # missing error handling
            # output mustn't be used!! (it would be saved in the variable $keywords in the main function)
        }        
    }

    # Erstellen einer Liste mit irrelevanten Wörtern
    $nonrelWords = Get-Content "C:\Users\ferocia\Documents\IGT\Wordlists\1000englWordsWithForms.txt" #nonrelevantWords
    $nonrelWords = $nonrelWords -replace '\d+', ''  # Zahlen werden rausgenommen
    $nonrelWordsList = [System.Collections.ArrayList]@()
    foreach($line in $nonrelWords)
    {
        $line = $line.split("`t")  # `t: tab
        foreach($word in $line)
        {
           if($word -ne '')
           {
            $nonrelWordsList.add($word) >$null
           }
        }     
    }
    $nonrelWords = Get-Content "C:\Users\ferocia\Documents\IGT\Wordlists\englPrepositions.txt"
    foreach($line in $nonrelWords)
    {       
        $nonrelWordsList.add($line) >$null               
    }

    $keyWords = [System.Collections.Hashtable]@{}

    # Tasks werden auf Schlüsselwörter reduziert
    # Für jede Tasksammlung eines Bpmns:
    foreach($taskname in ($tasks.keys))
    {
        # Die Wörter aller Tasks werden in einer Liste einzeln gespeichert.
        $wordList = [System.Collections.Hashtable]@{}
        $wordList.add($taskname,([System.Collections.ArrayList]($tasks.$taskname).toLower().replace('(','').replace(')','').split(" ")))
        # irrelevante Wörter werden aussortiert
        for($i = ($wordList.$taskname.count)-1; $i -ge 0; $i -= 1)
        {
            # Wenn das aktuelle Wort ein irrelevantes Wort ist oder weniger als drei Zeichen hat oder &amp; oder leer ist, wird es entfernt.
            if(($nonrelWordsList.Contains($wordList.$taskname[$i])) -or ($wordList.$taskname[$i].ToCharArray().Count -lt 3) -or ($wordList.$taskname[$i] -eq "&amp;") -or ($wordList.$taskname[$i] -eq ""))
            {
                $wordList.$taskname.Remove($wordList.$taskname[$i])
            }
        }
        $keyWords.Add($taskname, $wordList.$taskname) >$null
    }

    # Pro Bpmn wird die Häufigkeit des Auftretens der einzelnen Wörter gezählt und in keyWordsCounted abgespeichert
    $keyWordsCounted = [System.Collections.Hashtable]@{}
    foreach($name in ($keyWords.keys))
    {        
        $keyWordsCounted.Add($name, ($keyWords.$name|Group-Object|% { $h = @{} } { $h[$_.Name] = $_.Count } { $h })) >$null
    }
    $keyWordsCounted
}

function getSuitableServices($keyWords, $wsdl)
{
    $bestChoices = [System.Collections.Hashtable]@{}
    # for every bpmn file
    foreach($coll in ($keyWords.Keys))
    {             
        $wsdlScores = [System.Collections.Hashtable]@{} 
        # for every wsdl file
        foreach($singleWsdl in ($wsdl.keys))
        {
            $score = 0
            # for every single keyword in the bpmn file
            foreach($word in ($keyWords.$coll.keys))
            {                  
                # $wordCounter contains the number of appearances of $word in the wsdl file
                $wordCounter = ($wsdl.$singleWsdl| Select-String -AllMatches -Pattern $word |Select-Object -ExpandProperty Matches |Select-Object -ExpandProperty Value|Group-Object).Count               
                # The score of the wsdl file is the number of appearances of the $word in the bpmn multiplied with $wordCounter
                $score += $keyWords.$coll.$word * $wordCounter # every word is weighted with the number of appearances in the bpmn and the wsdl
            }  
            $wsdlScores.Add($singleWsdl, ($score/($keyWords.$coll.keys.count)))              
        }
        $bestChoices.Add($coll, $wsdlScores)            
    }
    $bestChoices
}

function showBestChoices($number, $bestChoices)
{
    foreach($coll in $bestChoices.keys)
    {
        $coll
        $bestChoices.$coll.GetEnumerator()|Sort-Object -Property value -Descending| Where-object {$_.value -ne 0} |Select -First $number
    }
}


main