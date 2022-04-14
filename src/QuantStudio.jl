module QuantStudio
using Delta2
using CSV
using DataFrames

export quantstudio

#make a singleton type for dispatch
struct QS end

quantstudio=QS()

"""
```julia
readpcr(quantstudio,filename)
```
Load a CSV file created by a QuantStudio instrument as a QPCRDataset.
"""
function Delta2.readpcr(::QS,csvfilename::AbstractString)::QPCRDataset
    tempbuf=IOBuffer()
    filestring=replace(read(csvfilename,String),"\r\n"=>"\n") #fix line endings if on windows
    filelines=split(filestring,"\n")
    #find the end of the header
    linenumber=1
    startline=missing
    endline=missing
    for line in filelines
        if ((split(line,",")[1] == "Well") && ismissing(startline)) #only want to take the first line that fits the bill
            #this is the line containing our column names
            startline=linenumber
        end

        if !ismissing(startline)
            #reject everything after an empty line
            if all(split(line,",") .== "")
                break
            end
            endline=linenumber
        end
        
        linenumber+=1
    end
    if ismissing(endline)
        goodlines=filelines[startline:end]
    else
        goodlines=filelines[startline:endline]
    end
    filetextnoheader=join(goodlines,"\n")
    write(tempbuf,filetextnoheader)
    seek(tempbuf,0)
    rawdata=CSV.read(tempbuf,DataFrame)
    close(tempbuf)
    ct_col=nothing
    if "CT" in names(rawdata)
        ct_col="CT"
    elseif "Cq" in names(rawdata)
        ct_col="Cq"
    else
        error("couldn't find CT column in dataset")
    end
    return QPCRDataset(rawdata,"Sample Name", "Target Name", ct_col, noamp_flag="Undetermined")
end

function askforpath()
    prompt="""
    please enter the path to your qpcr data
    this must be a .csv file in the format exported by a QuantStudio instrument
    tip: try dragging the file onto this window
    """
    println(prompt)
    response=strip(Delta2.escapechars,readline())
    println()
    return response
end
    
#wizard for performing DeltaCT
"""
```julia
DeltaCT(quantstudio)
```
Start a wizard for performing ΔCT on data collected using a QuantStudio instrument
"""
function Delta2.DeltaCT(::QS)
    println()
    readpcr(quantstudio,askforpath()) |> DeltaCT
end

#wizard for performing DDCT
"""
```julia
DDCT(quantstudio)
```
Start a wizard for performing ΔΔCT on data collected using a QuantStudio instrument
"""
function Delta2.DDCT(::QS)
    println()
    readpcr(quantstudio,askforpath()) |> DDCT
end

end # module
