`define RESET              10'h001 // reset MPU_6050
`define G_CONF             10'h043 // GYRO_CONFIG for self test
`define A_CONF             10'h085 // ACCEL_CONFIG for self test
`define G_A_CONF_0         10'h0C7 // full Scale Range: gyroscope - ± 250 °/s, accelerometer - ± 2g
`define G_A_CONF_1         10'h107 // full Scale Range: gyroscope - ± 500 °/s, accelerometer - ± 4g 
`define G_A_CONF_2         10'h127 // full Scale Range: gyroscope - ± 1000 °/s, accelerometer - ± 8g 
`define G_A_CONF_3         10'h147 // full Scale Range: gyroscope - ± 2000 °/s, accelerometer - ± 16g
`define SMPRT_DIV          10'h16C // sets Sample Rate = 1 KHz 
`define USER_CTRL_EN_FIFO  10'h1AE // user control : enable FIFO
`define USER_CTRL_DIS_FIFO 10'h1EE // user control: disable FIFO
`define FIFO_EN            10'h211 // FIFO enable for temperature, gyroscope and accelerometer
`define ACCEL_MSR          10'h253 // accelerometer measurements
`define TMP_MSR            10'h254 // measurement temperature
`define GYRO_MSR           10'h255 // gyroscope measurements
`define FIFO_COUNT         10'h256 // read FIFO count
`define FIFO_R_W           10'h257 // FIFO Read
`define SELF_TEST          10'h258 // read coefficients
`define CHECK              10'h259 // check WHO_AM_I