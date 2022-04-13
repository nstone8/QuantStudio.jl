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
    data=select(rawdata,"Sample Name" => function(s)
                    #make sure sample names are always Strings
                    string.(s)
                end => :sample,"Target Name"=>function(t)
                    #make sure targets are also strings
                    string.(t)
                    end => :target,"CT"=>ByRow(function(ct)
                                                                                      if ct=="Undetermined"
                                                                                          return Float64(40)
                                                                                      else
                                                                                          return parse(Float64,ct)
                                                                                      end
                                                                                  end)=>:ct)
    return QPCRDataset(data)
end

function askforpath()
    prompt="""
    Please enter the path to your qpcr data. This must be a .csv file in the format exported by a QuantStudio Instrument.
    Tip: try dragging the file onto this window
    """
    println(prompt)
    return strip(Delta2.escapechars,readline())
end
    
#wizard for performing DeltaCT
"""
```julia
DeltaCT(quantstudio)
```
Start a wizard for performing ΔCT on data collected using a QuantStudio instrument
"""
function Delta2.DeltaCT(::QS)
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
    readpcr(quantstudio,askforpath()) |> DDCT
end

end # module
