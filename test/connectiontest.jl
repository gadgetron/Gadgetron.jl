using Test
using Gadgetron
import Base.Threads.@spawn
using Random 

testheader = MRD.MRDHeader("""<?xml version="1.0"?>
<ismrmrdHeader xmlns="http://www.ismrm.org/ISMRMRD" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xs="http://www.w3.org/2001/XMLSchema" xsi:schemaLocation="http://www.ismrm.org/ISMRMRD ismrmrd.xsd">
  <subjectInformation>
    <patientName>phantom</patientName>
    <patientWeight_kg>70.3068</patientWeight_kg>
  </subjectInformation>
  <acquisitionSystemInformation>
    <systemVendor>SIEMENS</systemVendor>
    <systemModel>Avanto</systemModel>
    <systemFieldStrength_T>1.494</systemFieldStrength_T>
    <receiverChannels>32</receiverChannels>
    <relativeReceiverNoiseBandwidth>0.79</relativeReceiverNoiseBandwidth>
  </acquisitionSystemInformation>
  <experimentalConditions>
    <H1resonanceFrequency_Hz>63642459</H1resonanceFrequency_Hz>
  </experimentalConditions>
  <encoding>
    <trajectory>cartesian</trajectory>
    <encodedSpace>
      <matrixSize>
        <x>256</x>
        <y>140</y>
        <z>80</z>
      </matrixSize>
      <fieldOfView_mm>
        <x>600</x>
        <y>328.153125</y>
        <z>160</z>
      </fieldOfView_mm>
    </encodedSpace>
    <reconSpace>
      <matrixSize>
        <x>128</x>
        <y>116</y>
        <z>64</z>
      </matrixSize>
      <fieldOfView_mm>
        <x>300</x>
        <y>271.875</y>
        <z>128</z>
      </fieldOfView_mm>
    </reconSpace>
    <encodingLimits>
      <kspace_encoding_step_1>
        <minimum>0</minimum>
        <maximum>83</maximum>
        <center>28</center>
      </kspace_encoding_step_1>
      <kspace_encoding_step_2>
        <minimum>0</minimum>
        <maximum>45</maximum>
        <center>20</center>
      </kspace_encoding_step_2>
      <slice>
        <minimum>0</minimum>
        <maximum>0</maximum>
        <center>0</center>
      </slice>
      <set>
        <minimum>0</minimum>
        <maximum>0</maximum>
        <center>0</center>
      </set>
    </encodingLimits>
    <parallelImaging>
    <accelerationFactor>
      <kspace_encoding_step_1>1</kspace_encoding_step_1>
      <kspace_encoding_step_2>1</kspace_encoding_step_2>
    </accelerationFactor>
    <calibrationMode>other</calibrationMode>
  </parallelImaging>
  </encoding>
  
  <sequenceParameters>
    <TR>4.6</TR>
    <TE>2.35</TE>
    <TI>300</TI>
  </sequenceParameters>
</ismrmrdHeader>""")

function parrotserver(port)
	t = @spawn begin
		connection = listen(port)
		for msg in connection
			put!(connection,msg)
		end
		close(connection)
	end
	return t 

end

function send_and_receive(connection,data )
		put!(connection,data)
		return take!(connection)
end

random_waveform_header() = MRD.WaveformHeader( [rand(Random.TaskLocalRNG(),ftype) for ftype in fieldtypes(MRD.WaveformHeader)]...)

@testset "Connection" begin 
	port = 9002
	server = parrotserver(port)
  config = "< _ />"
  header = testheader
  connection = connect("localhost",port,config,header )

  data = randn(Random.TaskLocalRNG(),ComplexF32,(192,32))
	acq = MRD.Acquisition(MRD.AcquisitionHeader(),data)
  @test acq == send_and_receive(connection,acq)

  wav = MRD.Waveform(random_waveform_header(),rand(Random.TaskLocalRNG(),UInt32,(64,8)))
  @test wav == send_and_receive(connection,wav)

  img = MRD.Image(MRD.ImageHeader(),randn(Random.TaskLocalRNG(),ComplexF32,(256,256,3,1)))
  @test img == send_and_receive(connection,img)

  close(connection)
	wait(server)
end