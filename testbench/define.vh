`define G_A_CONF_0         10'h022 // full Scale Range: gyroscope - ± 250 °/s, accelerometer - ± 2g
`define G_A_CONF_1         10'h062 // full Scale Range: gyroscope - ± 500 °/s, accelerometer - ± 4g 
`define G_A_CONF_2         10'h082 // full Scale Range: gyroscope - ± 1000 °/s, accelerometer - ± 8g 
`define G_A_CONF_3         10'h0A2 // full Scale Range: gyroscope - ± 2000 °/s, accelerometer - ± 16g
`define FIFO_EN            10'h0C7 // FIFO enable for temperature, gyroscope and accelerometer
`define ACCEL_MSR          10'h008 // accelerometer measurements
`define TMP_MSR            10'h009 // measurement temperature
`define GYRO_MSR           10'h00A // gyroscope measurements
`define USER_CTRL_EN_FIFO  10'h16C // user control : enable FIFO
`define USER_CTRL_DIS_FIFO 10'h1AC // user control: disable FIFO
`define FIFO_COUNT         10'h00E // read FIFO count
`define CHECK              10'h00F // check WHO_AM_I