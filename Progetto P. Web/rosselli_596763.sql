-- Progettazione Web 
DROP DATABASE if exists rosselli_596763; 
CREATE DATABASE rosselli_596763; 
USE rosselli_596763; 
-- MySQL dump 10.13  Distrib 5.7.28, for Win64 (x86_64)
--
-- Host: localhost    Database: rosselli_596763
-- ------------------------------------------------------
-- Server version	5.7.28

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `partita`
--

DROP TABLE IF EXISTS `partita`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `partita` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(60) NOT NULL,
  `bestScore` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `partita`
--

LOCK TABLES `partita` WRITE;
/*!40000 ALTER TABLE `partita` DISABLE KEYS */;
INSERT INTO `partita` VALUES (1,'Deni',2996),(2,'Luca',408),(3,'Noemi',1308),(4,'Silvia',832),(5,'Daniel',2256),(6,'Alessandro',884),(7,'Boncia',1028),(8,'Vitto',1212),(9,'Giorgio',1352),(10,'Samuel',1168),(11,'Eleonora',2292),(12,'Oliver',1076),(13,'Miriam',0),(14,'Denise',1600);
/*!40000 ALTER TABLE `partita` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `utente`
--

DROP TABLE IF EXISTS `utente`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `utente` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(60) NOT NULL,
  `password` varchar(60) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `utente`
--

LOCK TABLES `utente` WRITE;
/*!40000 ALTER TABLE `utente` DISABLE KEYS */;
INSERT INTO `utente` VALUES (1,'Deni','$2y$10$YH1p8k0Pt6/BkgsSdxaXCugNHwvB5kqvMjxvO/17umsaPQja6yd.q'),(2,'Luca','$2y$10$jQHzNP31WO9Bz.GU.Pb9auMjPlQccYmo4adBMeNW3/MPmg0E1gGAO'),(3,'Noemi','$2y$10$cAOENObKdo7V0mBQtVK8BOu0H3ptIvhKL6MKwEE7SLf1kZeauxuLa'),(4,'Silvia','$2y$10$lVBbD3MdQqxnxLxBXLdQNu/EeUHgHWrY6VHqV8yARpydgQ4Oxb.6C'),(5,'Daniel','$2y$10$0ut3oe4nJu3v7RNs6FWhA.WztT3SWCxOuQ8vCpbgwxRN4Wr2T5Ace'),(6,'Alessandro','$2y$10$qLFiTP14b.c1e3Icb/xvtOhuoXB1OvrS/uZNykued0Or8idjQwJES'),(7,'Boncia','$2y$10$Er624MMtshJXBU312y8rv.cUONA8crYZVF9BMhZS6zuaNF6/bpyXi'),(8,'Vitto','$2y$10$/41AoW/gQBiaoM0Q0h1ijeiGdOkft.0pGox20QoayLuItvN.q0MFi'),(9,'Giorgio','$2y$10$/cDN83omB2y8L9Y96YuPWOMINWCb7cZjlwv2YtuBYi0kKhQvyp/qi'),(10,'Samuel','$2y$10$l/SG985l23o1fbe6CIr8yucalxLBIfE1DeFD1HtbWFkrHK/w5dZvS'),(11,'Eleonora','$2y$10$GBBSdBErIN3IedLrt71OUOWcJ36Yn1FpqJu.pGUnCQqUKqWd6kwcW'),(12,'Oliver','$2y$10$oIm/l1ECiONz.GBR0VxmDuWrcC4V4tdYc2grFEjSeadaa7cKiWfYO'),(13,'Miriam','$2y$10$WF7kyMi3SLhV4Re8/ZE4duw/sMTplUMGLIknl3jUmBG.538PnVUwq'),(14,'Denise','$2y$10$p1VF5odo.CWtB7rcQLJS2.1ucPzovJngPcNX86sOinopyqKiRtKKy');
/*!40000 ALTER TABLE `utente` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-11-13 16:05:17
